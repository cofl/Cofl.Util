Hello r/PowerShell! Here again with another script from work, but maybe a useful one this time.

At my job, we use Git to manage the source files for our internal documentation websites. Hundreds of files of clean Markdown, and then all the other junk that goes with it. Not all of that needs to be deployed to production, but all of it *does* need to be checked in to Git.

There are a couple of ways that this sort of exclusion when deploying could be done:

1. Keep a list of paths to exclude relative to the root of the repository, then prepend them with the current directory in the deploy script and use `Get-ChildItem -Exclude $Patterns | Copy-Item ...`.
2. Trickery with Linux commands or screwing around with Git and ignore files.
3. Actually that last one sounds useful, but how 'bout we keep it all in the PowerShell world?

And so, `Get-FilteredChildItem` was created. `Get-FilteredChildItem` is a C# Cmdlet emulates the functionality of [`.gitignore`](https://git-scm.com/docs/gitignore) files to filter out files and directories in a large hierarchy, using ordered pattern definitions declared in flat files.

Below follows a neatly formatted version of the script, split up for easy reading and less scrolling to the side. The full version is available from [GitHub](https://github.com/cofl/Cofl.Util/blob/master/src/Cofl.Util/GetFilteredChildItemCmdlet.cs) as part of Cofl.Util, alongside [its Pester tests](https://github.com/cofl/Cofl.Util/blob/master/tests/Get-FilteredChildItem.Tests.ps1). I've been testing with local files on Windows, but I have confirmed that it works just fine with UNC paths, and also in the PowerShell 7.0 preview.

---

### .Synopsis
Enumerates files using .gitignore-like flat-file filters.

### .Description
Get-FilteredChildItem uses flat-file filters to enumerate files in directory hierarchies similar to `.gitignore` files. A best-effort attempt is made to be compatible with the syntax of `.gitignore` files, which can be read online [here](https://git-scm.com/docs/gitignore#_pattern_format).

The use of Unix directory separators (`/`) is mandatory in patterns.

### .Examples

1. Lists files under the directory `$Path` that aren't excluded by patterns declared in files with the name `.gitignore`.

        PS C:\> Get-FilteredChildItem -Path $Path -IgnoreFileName .gitignore
2. Lists files under the directory `$Path` that aren't excluded by the patterns passed to the parameter `IgnorePattern`.

        PS C:\> Get-FilteredChildItem -Path $Path -IgnorePattern 'pattern1', 'pattern2', 'etc'
3. Lists files under the directory `$Path` that are excluded by patterns declared in files with the name `.gitignore`.

        PS C:\> PS C:\> Get-FilteredChildItem -Path $Path -IgnoreFileName .gitignore -Ignored
4. Lists only hidden files under the directory `$Path` that aren't excluded by patterns declared in files with the name `.gitignore`.

        PS C:\> Get-FilteredChildItem -Path $Path -IgnoreFileName .gitignore -Hidden
5. Lists both hidden and non-hidden files under the directory `$Path` that aren't excluded by patterns declared in files with the name `.gitignore`.

        PS C:\> Get-FilteredChildItem -Path $Path -IgnoreFileName .gitignore -Force
6. Lists directories under the directory `$Path` that contain files that aren't excluded by patterns declared in files with the name `.gitignore`.

        PS C:\> Get-FilteredChildItem -Path $Path -IgnoreFileName .gitignore -Directory
7. Lists files under the directory `$Path` that aren't excluded by patterns declared in files with the name `.gitignore`, up to a maximum directory depth of 1 (the enumeration will include the contents of the immediate subdirectories of the directory `$Path`).

        PS C:\> Get-FilteredChildItem -Path $Path -IgnoreFileName .gitignore -Depth 1

---

### The Code

This cmdlet is C#, and so makes use of a lot of .NET classes. Right at the top of the file, we import the namespaces of those classes so we don't have to type so much later. We also alias two of the classes to other names, because `Path` and `Directory` are also variables, and the compiler prefers those over class names. It's also good practice to put C# classes in namespaces, so we do that, too, using the name of the module as the namespace.

    using System.Collections.Generic;
    using System.IO;
    using System.Management.Automation;
    using System.Text.RegularExpressions;
    using IOPath = System.IO.Path;
    using IODirectory = System.IO.Directory;

    namespace Cofl.Util
    {

Next, the cmdlet definition. If this were in PowerShell, we'd use the `[CmdletBinding()]` attribute to make it an [Advanced Function](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced) and gain access to some more powerful features, but in C# we need two parts:

1. The `[Cmdlet]` attribute, to name our class as a cmdlet in PowerShell.
2. Inheriting from the `PSCmdlet` class, so we have access to the path resolver methods.

We also throw an `[OutputType]` attribute here so PowerShell's intellisense knows what's coming its way.

        [Cmdlet(VerbsCommon.Get, "FilteredChildItem", DefaultParameterSetName = nameof    (GetFilteredChildItemCmdlet.ParameterSets.Default))]
        [OutputType(typeof(FileInfo), typeof(DirectoryInfo))]
        public sealed class GetFilteredChildItemCmdlet : PSCmdlet
        {

The two parameter sets this cmdlet supports are *Default* and *Literal*, split along the same line as `Get-ChildItem`'s parameter sets: the LiteralPath parameter, which doesn't process wildcards. I use an enum to define the names so I can use [`nameof`](https://docs.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/nameof) and avoid mis-typing them &mdash; the compiler will check that these names, where they're used, are right.

            private enum ParameterSets
            {
                Default,
                Literal
            }

The `Path` parameter isn't required. In binary cmdlets, parameters are given as [properties](https://docs.microsoft.com/en-us/dotnet/csharp/programming-guide/classes-and-structs/properties). We can assign our defaults the same way as normal; here, the default is the current location. It is possible to pass in multiple paths, either as an array, or via the pipeline. With `Path`, [wildcards](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_wildcards?view=powershell-6) like `*` and `?` are processed, so something like `$BaseDir/*/inner` is possible. If a file is given instead of a directory, the only way to filter names is via the `IgnorePattern` parameter, which uses the file's parent directory as the base path.

            [Parameter(ValueFromPipeline = true, ValueFromPipelineByPropertyName = true, Position = 0,     ParameterSetName = nameof(ParameterSets.Default))]
            [SupportsWildcards]
            public string[] Path { get; set; } = new[]{ "." };

`LiteralPath` is similar to `Path`, except it doesn't support wildcards at all. This is useful if you have things like `[x64]` in your file or folder names; if such a path was given to `Path`, it would match an `x`, a `6`, or a `4`, but not `[x64]` &mdash; with `LiteralPath`, it's the opposite. `LiteralPath` is also aliased with `PSPath`, and accepts pipeline input by property names.

            [Parameter(Mandatory = true, ValueFromPipelineByPropertyName = true, ParameterSetName = nameof    (ParameterSets.Literal))]
            [Alias("PSPath")]
            public string[] LiteralPath { get; set; }

The `IgnoreFileName` parameter is given the name of the files to ignore. If you wanted to ignore everything Git did, for example, you'd tell it `'.gitignore'`. Normally, ignore files are left out of the output, but you can enable them being processed like all other files with the `IncludeIgnoreFiles` switch.

            [Parameter]
            [ValidateNotNullOrEmpty][Alias("ifn")]
            public string IgnoreFileName { get; set; }

`IgnorePattern` allows pattern rules that would have been defined in an ignore file (see previous parameter) to be defined as a string or string array. Rules added here are inserted first, before any other rules, as if they were declared at the top of an ignore file in the directory given to `Path`.

            [Parameter]
            public string[] IgnorePattern { get; set; }

By default, ignore files are skipped in the output as if they weren't even there. You can, however, force them to be included (unless a pattern leaves them out) with the `IncludeIgnoreFiles` switch.

            [Parameter]
            public SwitchParameter IncludeIgnoreFiles { get; set; }

Of course, some times you don't want the files themselves, but instead the directories that contain them. Providing the `Directory` switch will enable that behavior.

            [Parameter]
            [Alias("d", "ad")]
            public SwitchParameter Directory { get; set; }

The last few parameters are all for limiting or allowing files in other ways: `-Depth` limits how many folders down from the one given in `-Path` that the cmdlet will check for files. `-Force` will allow the cmdlet to check hidden files and folders, and `-Hidden` will tell the cmdlet to check for *only* hidden files and folders.

            [Parameter]
            public uint Depth { get; set; } = uint.MaxValue;

            [Parameter]
            [Alias("ah")]
            public SwitchParameter Hidden { get; set; }

            [Parameter]
            public SwitchParameter Force { get; set; }

The last parameter is `Ignored`, which inverts the output behavior: if a file would have been output, it isn't, and if it would have been skipped, it's now output to the pipeline.

            [Parameter]
            public SwitchParameter Ignored { get; set; }

Finally done with the parameters, but not with the initialization in general. There are a number of regular expressions that are statically defined, as well as a delegate, and a number of variables that are shared between various support functions.

1. `CommentLine`, which matches lines in ignore files that should be skipped over. Comments can be added by starting the line with any amount of whitespace, then `#`, but empty or otherwise blank lines are also matched by this.
2. `TrailingWhitespace` is used to trim all un-escaped whitespace from the end of a line. Because files may end in whitespace, it's possible to escape that whitespace with a `\` character. Any whitespace after the last escaped whitespace is trimmed off.
3. `UnescapeCharacters` is another replacement regex that removes backslashes from the start of the line, and from before any whitespace.
4. `UnescapePatternCharacters` does the same thing, but for characters that have a special meaning in patterns: `?`, `*`, `\`, and `[`. These are processed later, which is why this regex is separate from the last one.
5. `GlobPatterns`. The Big One. This regex is used along with `GlobPatternEvaluator` to turn the friendly wildcard patterns from files into nasty regular expressions.
6. `Queue` keeps track of which directories we still need to visit (or re-visit).
7. `DirectoryHasValidChildren` and `OutputDirectories` make the `Directory` switch work by tracking which directories need to be output; the second stack is necessary because we can only know what directories are valid *after* visiting all their children, and they're re-visited in *reverse* order.
8. `IgnoreRulePerDirectoryCounts` is used to track how many rules were added in each directory, so that many rules can be removed from the list when we leave it.

We also define a few string constants, the names of the match groups in `GlobPatterns`. This is like what we did up above with `enum ParameterSets`, but with even less typing (though there is manually string association).

            private static Regex CommentLine = new Regex(@"^\s*(?:#.*)?$");
            private static Regex TrailingWhitespace = new Regex(@"(?:(?<!\\)\s)+$");
            private static Regex UnescapeCharacters = new Regex(@"^\\|\\(?=\s)");
            private static Regex UnescapePatternCharacters = new Regex(@"^\\(?=[\[\\\*\?])");

            private const string SetGroup = "Set";
            private const string GlobGroup = "Glob";
            private const string StarGroup = "Star";
            private const string AnyGroup = "Any";
            private const string TextGroup = "Text";
            
            private static Regex GlobPatterns = new Regex(string.Join("|", $@"(?<!\\)\[(?<{SetGroup}>[^/]+)\]",
                                                                    $@"(?<{GlobGroup}>/\*\*)",
                                                                    $@"(?<{StarGroup}>(?<!\\)\*)",
                                                                    $@"(?<{AnyGroup}>(?<!\\)\?)",
                                                                    $@"(?<{TextGroup}>(?:[^/?*[]|(?<=\\)[?*[])+)"));

            private static string GlobPatternEvaluator(Match match)
            {

In this delegate, we replace the various glob patterns with regex patterns, and escape all other text (except /).

                if(match.Groups[TextGroup].Success)
                    return Regex.Escape(UnescapePatternCharacters.Replace(match.Groups[TextGroup].Value, ""));
                if(match.Groups[StarGroup].Success)
                    return "[^/]*";
                if(match.Groups[GlobGroup].Success)
                    return "(/.*)?";
                if(match.Groups[AnyGroup].Success)
                    return ".";
                // else MatchGroups.Set
                var escaped = Regex.Escape(match.Groups[SetGroup].Value);
                return escaped[0] == '!' ? $"[^{escaped.Substring(1)}]" : $"[{escaped}]";
            }

            private LinkedList<DirectoryInfo> Queue = new LinkedList<DirectoryInfo>();
            private Dictionary<string, bool> DirectoryHasValidChildren = new Dictionary<string, bool>();
            private Stack<DirectoryInfo> OutputDirectories = new Stack<DirectoryInfo>();
            private Dictionary<string, uint> IgnoreRulePerDirectoryCounts = new Dictionary<string, uint>();

Each rule is stored in a structure; in another version, this was a tuple, but not that we're in C#, we can use these to gain some readability.

The struct can't work alone, though, so there's also the `IgnoreRules` list, which keeps track of all the rules defined in reverse order, so the last rule is first.

            private struct IgnoreRule
            {
                public readonly bool IsDirectoryRule;
                public readonly bool IsExcludeRule;
                public readonly Regex Pattern;
    
                public IgnoreRule(bool isDirectoryRule, bool isExcludeRule, Regex pattern)
                {
                    IsDirectoryRule = isDirectoryRule;
                    IsExcludeRule = isExcludeRule;
                    Pattern = pattern;
                }
            }
            private LinkedList<IgnoreRule> IgnoreRules = new LinkedList<IgnoreRule>();

With `IgnoreRules` outside the function, we can create another function, `byte AddPatternRule(string, string)`, to process each pattern into a rule and add it to the list, returning `0` or `1` depending on how many rules it added (it can only do one rule at a time).

            private byte AddPatternRule(string basePath, string pattern)
            {
                if(null == pattern || CommentLine.IsMatch(pattern))
                    return 0;
                pattern = pattern.TrimStart();
                var isExcludeRule = pattern[0] == '!';
                if(isExcludeRule)
                    pattern = pattern.Substring(1);
                pattern = UnescapeCharacters.Replace(TrailingWhitespace.Replace(pattern, ""), "");
                if(pattern[0] != '/')
                    pattern = $"/**/{pattern}";
                var isDirectoryRule = pattern[pattern.Length - 1] == '/';
                if(!isDirectoryRule)
                    pattern = $"{pattern}/**";
                var rule = new Regex($"^{basePath}{GlobPatterns.Replace(pattern, GlobPatternEvaluator)}$");
                IgnoreRules.AddFirst(new IgnoreRule(isDirectoryRule, isExcludeRule, rule));
                return 1;
            }

`uint AddIgnorePatterns(string)` *can* do more than one pattern, but only for the `IgnorePattern` parameter. It returns the total number of rules added from that set.

            private uint AddIgnorePatterns(string basePath)
            {
                uint counter = 0;
                if(IgnorePattern != null)
                    foreach(var pattern in IgnorePattern)
                        counter += AddPatternRule(basePath, pattern);
                return counter;
            }

Next, here's the function that takes all those paths we passed in and turns them into nice, clean, normal, full paths. `enumerable` is either `Path` or `LiteralPath`; `literal` is how we should process them. To make it easy, this is an [generator](https://docs.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/yield), so we don't need to deal with all the items all at once.

            private IEnumerable<FileSystemInfo> ResolvePaths(IEnumerable<string> enumerable, bool literal)
            {
                if(null == enumerable)
                    yield break;
                foreach(var item in enumerable)
                {
                    if(string.IsNullOrEmpty(item))
                        continue;
                    if(!literal)
                    {
                        // GetResolvedProviderPathFromPSPath expands wildcards
                        var result = GetResolvedProviderPathFromPSPath(item, out var provider);
                        if(null != result)
                        {
                            foreach(var path in result)
                            {
                                if(IODirectory.Exists(path))
                                    yield return new DirectoryInfo(path);
                                else
                                    yield return new FileInfo(path);
                            }
                        }
                    } else
                    {
                        // GetUnresolvedProviderPathFromPSPath, though, does not.
                        var result = GetUnresolvedProviderPathFromPSPath(item);
                        if(IODirectory.Exists(result))
                            yield return new DirectoryInfo(result);
                        else
                            yield return new FileInfo(result);
                    }
                }
            }

After declaring all that, we can finally get to work.

            protected override void ProcessRecord()
            {
                var isLiteral = LiteralPath != null && LiteralPath.Length > 0;
                foreach(var path in ResolvePaths(isLiteral ? LiteralPath : Path, isLiteral))
                {

For every processed path, we need to clear out the rules we've already added.

                    IgnoreRules.Clear();

If the current path is a file, handle it in a special way.

                    if(!path.Attributes.HasFlag(FileAttributes.Directory))
                    {
                        // skip out early if the file is an ignore file and those aren't included.
                        if(path.Name == IgnoreFileName && !IncludeIgnoreFiles)
                            continue;
                        AddIgnorePatterns(((FileInfo) path).DirectoryName.Replace('\\', '/'));
                        ProcessFileSystemItem(path);
    
                        // then, skip ahead to write out any directories for this item, and continue.
                        goto WriteDirectories;
                    }

Otherwise, we clean up some other state-trackers and get ready to deal with a directory.

                    Queue.Clear();
                    IgnoreRulePerDirectoryCounts.Clear();
                    DirectoryHasValidChildren.Clear();
                    
                    // add the next item and begin.
                    Queue.AddFirst((DirectoryInfo) path);
                    
                    uint currentDepth = 0;
                    var ignoreRuleCount = AddIgnorePatterns(Regex.Escape(
                        Queue.First.Value.FullName.Replace('\\', '/')));
                    while(Queue.Count > 0)
                    {
                        var nextNode = Queue.First;
                        var top = nextNode.Value;
    
                        if(IgnoreRulePerDirectoryCounts.ContainsKey(top.FullName))
                        {

If this is the second time we've seen this node, remove the rules  for this directory from the list. Then, remove this directory from the map (we won't see it again, so save some memory).

                            ignoreRuleCount = IgnoreRulePerDirectoryCounts[top.FullName];
                            for(; ignoreRuleCount > 0; ignoreRuleCount -= 1)
                                IgnoreRules.RemoveFirst();
                            IgnoreRulePerDirectoryCounts.Remove(top.FullName);
                            Queue.RemoveFirst();
                            currentDepth -= 1;
    
                            if(DirectoryHasValidChildren.ContainsKey(top.FullName))
                            {

If directories are being output, push them onto a stack. Directories are re-encountered in reverse order, so they need to be re-reversed before being output.

                                OutputDirectories.Push(top);
                                DirectoryHasValidChildren[top.Parent.FullName] = true;
                                DirectoryHasValidChildren.Remove(top.FullName);
                            }
                            continue;
                        }
    
                        currentDepth += 1;

The first thing we do in a new directory is look for an ingore file and add its rules if one exists.

                        if(!string.IsNullOrEmpty(IgnoreFileName))
                        {
                            var ignoreFile = new FileInfo(IOPath.Combine(top.FullName, IgnoreFileName));
                            if(ignoreFile.Exists && !ignoreFile.Attributes.HasFlag(FileAttributes.Directory))
                            {
                                var basePath = Regex.Escape(top.FullName.Replace('\\', '/'));
                                using(var reader = new StreamReader(ignoreFile.OpenRead()))
                                    // Process each line of the file as a new rule.
                                    for(var line = reader.ReadLine(); null != line; line = reader.ReadLine())
                                        ignoreRuleCount += AddPatternRule(basePath, line);
                            }
                        }

For each directory in our stack from where we are now up to the root of the search, we keep track of how many rules were added in that directory. The next time this directory is at the front of the queue, all its children will have been processed, so we can remove the rules associated with this directory.

Then, for each file or directory, we process it. `skipRemainingFiles` is a small optimization for the `Directory` switch to avoid iterating over the ignore rules for files whose parent directory has already been okayed for output.

                        IgnoreRulePerDirectoryCounts[top.FullName] = ignoreRuleCount;
                        ignoreRuleCount = 0;
    
                        var skipRemainingFiles = false;
                        using(var entries = top.EnumerateFileSystemInfos().GetEnumerator())
                        while(entries.MoveNext())
                            skipRemainingFiles = ProcessFileSystemItem(entries.Current, currentDepth,
                                                                       nextNode, skipRemainingFiles);
                    }

You may be familiar with `goto`. Some say they're bad. Here, I say they save a lot of indenting. There's just one more part to *this* function, if we're outputting directories instead of files. Because directories are re-visited backwards, they need to be put on a stack, and then all popped off at the end.

                    WriteDirectories:
                    // If there are directories to output, output them in the right order.
                    while(OutputDirectories.Count > 0)
                        WriteObject(OutputDirectories.Pop());
                }
            }

There's just one more function, I promise. Here, we have `ProcessFileSystemItem`, the guts that actually does the filtering.

            private bool ProcessFileSystemItem(FileSystemInfo item, uint currentDepth = 0,
                LinkedListNode<DirectoryInfo> nextNode = null, bool skipRemainingFiles = false)
            {
                var isDirectory = item.Attributes.HasFlag(FileAttributes.Directory);

If this is a file and those are being skipped right now, skip over it.

                if(!isDirectory && skipRemainingFiles)
                    return true;

If this is an ignore file and those shouldn't be processed, skip over it.

                if(!isDirectory && !IncludeIgnoreFiles && item.Name == IgnoreFileName)
                    return false;
                var isHidden = item.Attributes.HasFlag(FileAttributes.Hidden);

If this is a hidden file and we're not supposed to show those, or this isn't a hidden file and $Hidden is true, then skip this item. Directories have to be searched always, in case they have hidden children but aren't hidden themselves.

                if(!isDirectory && !Force && (Hidden != isHidden))
                    return false;

If we aren't looking for hidden files at all and this directory is hidden, skip it.

                if(isDirectory && isHidden && !(Force || Hidden))
                    return false;
                var itemName = item.FullName.Replace('\\', '/');

All the directory-only rules match a '/' at the end of the item name; the non-directory-only rules also match the '/', but it can be not at the end.

                if(isDirectory)
                    itemName += '/';

Then, for each rule (in reverse order of declaration, as that's how they're stored), check the name, stopping once we hit a rule that applies.

                foreach(var rule in IgnoreRules)
                {
                    // Skip directory ignore rules for files.
                    if(rule.IsDirectoryRule && !isDirectory)
                        continue;

This next check can be a bit complicated to follow; it took me a good few minutes to grok what needed to happen when I wrote it. If the rule matched the item, and we aren't outputting ignored items, then if the rule is an allow rule and we aren't outputting ignored items, handle the item.

Otherwise, if the rule didn't match the item and we are outputting ignored items, then if the rule is an ignore rule and we're outputting ignored items, handle the item.

                    if(rule.Pattern.IsMatch(itemName) != Ignored.IsPresent)
                    {
                        // If this is an exclusion/allow rule, go to the write-out part.
                        if(rule.IsExcludeRule != Ignored)
                            goto Output;
                        // Otherwise, we're done here
                        return false;
                    }
                }

If no rule ignored the file, and we only want to output ignored files, then this will skip to the next item.

                if(Ignored)
                    return false;

At the end, though, there's the common output-handling code for all cases that need to output or change the output state somehow:

- Directories are recursed into if we're supposed to.
- Or, if it's a file:

   1. If outputting a directory, mark the directory this file is in as valid.
   2. Or, output the file to the pipeline now.

We return `true` if the directory was marked as valid, so the next time this is called, it'll skip files.

                Output:
                if(isDirectory)
                {
                    if(currentDepth <= Depth)
                        Queue.AddBefore(nextNode, (DirectoryInfo) item);
                } else if(Directory)
                {
                    DirectoryHasValidChildren[((FileInfo) item).DirectoryName] = true;
                    return true;
                } else
                {
                    WriteObject((FileInfo) item);
                }
                return false;
            }
        }
    }

---

If you're still here, all the way down at the bottom, thanks for sticking with me the whole way through that!

I also want to give a special thanks to /u/lordicarus, who provided insightful comments that led to some great improvements in how the cmdlet behaves, such as accepting files.

If you want to give it a try, it's available either in source on GitHub, or from the PowerShellGallery in the [Cofl.Util](https://www.powershellgallery.com/packages/Cofl.Util/1.2.0) module version 1.2 or higher.

TL;DR: [`Get-FilteredChildItem`](https://github.com/cofl/Cofl.Util/blob/master/src/Cofl.Util/GetFilteredChildItemCmdlet.cs) emulated `.gitignore` files' patterns to arbitrarily match large file hierarchies.
