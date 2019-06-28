Hello r/PowerShell! Here again with another script from work, but maybe a useful one this time.

At my job, we use Git to manage the source files for our internal documentation websites. Hundreds of files of clean Markdown, and then all the other junk that goes with it. Not all of that needs to be deployed to production, but all of it *does* need to be checked in to Git.

There are a couple of ways that this sort of exclusion when deploying could be done:

1. Keep a list of paths to exclude relative to the root of the repository, then prepend them with the current directory in the deploy script and use `Get-ChildItem -Exclude $Patterns | Copy-Item ...`.
2. Trickery with Linux commands or screwing around with Git and ignore files.
3. Actually that last one sounds useful, but how 'bout we keep it all in the PowerShell world?

And so, `Get-FilteredChildItem` was created. `Get-FilteredChildItem` emulates the functionality of [`.gitignore`](https://git-scm.com/docs/gitignore) files to filter out files and directories in a large hierarchy, using ordered pattern definitions declared in flat files.

Below follows a neatly formatted version of the script, split up for easy reading and less scrolling to the side. The full version is available from [GitHub](https://gist.github.com/cofl/52816571c805161c75ac44dfc8634a93), alongside its Pester tests.

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

### The Script

This script makes use of a lot of .NET classes. Right at the top of the file, we import the namespaces of those classes so we don't have to type so much later.

    using namespace System
    using namespace System.Collections.Generic
    using namespace System.IO
    using namespace System.Text.RegularExpressions

Next, the function definition. This is an [Advanced Function](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_functions_advanced) that makes use of the `[CmdletBinding()]` attribute to define parameter sets. We also define our output type to be `System.IO.FileSystemInfo`, which is the base class shared by both File and Directory information objects (this cmdlet can output either one).

    function Get-FilteredChildItem
    {
        [CmdletBinding(DefaultParameterSetName='Default')]
        [OutputType([System.IO.FileSystemInfo])]
        PARAM (

The `Path` parameter is required, and must be a directory. It can come either from a string, or from a `DirectoryInfo` object,
and can take input from the pipeline.

            [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
                [Alias('LiteralPath')]
                [Alias('PSPath')]
                [DirectoryInfo]$Path,

The `IgnoreFileName` parameter is given the name of the files to ignore. If you wanted to ignore everything Git did, for example, you'd tell it `'.gitignore'`. Normally, ignore files are left out of the output, but you can enable them being processed like all other files with the `-IncludeIgnoreFiles` switch.

            [Parameter()]
                [Alias('ifn')]
                [string]$IgnoreFileName,
            [Parameter(ParameterSetName='Default')]
                [switch]$IncludeIgnoreFiles,

`IgnorePattern` allows pattern rules that would have been defined in an ignore file (see previous parameter) to be defined as a string or string array. Rules added here are inserted first, before any other rules, as if they were declared at the top of an ignore file in the directory given to `-Path`.

            [Parameter()]
                [Alias('ip')]
                [string[]]$IgnorePattern,

Of course, some times you don't want the files themselves, but instead the directories that contain them. Providing the `-Directory` switch will enable that behavior.

            [Parameter(Mandatory=$true,ParameterSetName='Directory')]
                [Alias('ad')]
                [Alias('d')]
                [switch]$Directory,

The last few parameters are all for limiting or allowing files in other ways: `-Depth` limits how many folders down from the one given in `-Path` that the cmdlet will check for files. `-Force` will allow the cmdlet to check hidden files and folders, and `-Hidden` will tell the cmdlet to check for *only* hidden files and folders.

            [Parameter()]
                [uint32]$Depth = [uint32]::MaxValue,
            [Parameter()]
                [Alias('ah')] # like Get-ChildItem
                [switch]$Hidden,
            [Parameter()]
                [switch]$Force,

The last parameter is `Ignored`, which inverts the output behavior: if a file would have been output, it isn't, and if it would have been skipped, it's now output to the pipeline.

            [Parameter()]
                [switch]$Ignored
        )

Finally done with our parameters, we get to the `begin` block that runs once for all directories given to `-Path` on the pipeline. I use it to declare regular expressions, delegates, and functions that I'll use throughout the rest of the script:

1. `[regex]$CommentLine`, which matches lines in ignore files that should be skipped over. Comments can be added by starting the line with any amount of whitespace, then `#`, but empty or otherwise blank lines are also matched by this.
2. `[regex]$TrailingWhitespace` is used to trim all un-escaped whitespace from the end of a line. Because files may end in whitespace, it's possible to escape that whitespace with a `\` character. Any whitespace after the last escaped whitespace is trimmed off.
3. `[regex]$UnescapeCharacters` is another replacement regex that removes backslashes from the start of the line, and from before any whitespace.
4. `[regex]$UnescapePatternCharacters` does the same thing, but for characters that have a special meaning in patterns: `?`, `*`, `\`, and `[`. These are processed later, which is why this regex is separate from the last one.
5. `[regex]$GlobPatterns`. The Big One. This regex is used along with `[MatchEvaluator]$GlobPatternEvaluator` to turn the friendly wildcard patterns from files into nasty regular expressions.
6. `[LinkedList[DirectoryInfo]]$Queue` keeps track of which directories we still need to visit.
7. `[LinkedList[Tuple[bool,bool,regex]]]$IgnoreRules` keeps each pattern, in reverse order of their declaration (in `.gitignore` files, the last pattern defined that matches is the one that applies). Each pattern is kept with a pair of boolean values the determine if the pattern is an exception, and if the pattern only applies to directories or not.
8. `[Dictionary[string,uint32]]$IgnoreRulePerDirectoryCounts` is used to track how many rules were added in each directory, so that many rules can be removed from the list when we leave it.
9. `[Dictionary[string,bool]]$DirectoryHasValidChildren` and `[Stack[DirectoryInfo]]$OutputDirectories` are integral to the functionality of the `-Directory` switch.
10. `[uint32]$CurrentDepth` makes the `-Depth` parameter possible.
11. And finally, `function Add-PatternRule`, when given a directory name and a pattern from a file or the `-IgnorePattern` parameter, can convert and add that pattern to the `$IgnoreRules` list, returning 1 if it added a rule to the list, and 0 if it didn't.

        begin
        {
            [regex]$CommentLine = [regex]::new('^\s*(?:#.*)?$')
            [regex]$TrailingWhitespace = [regex]::new('(?:(?<!\\)\s)+$')
            [regex]$UnescapeCharacters = [regex]::new('^\\|\\(?=\s)')
            [regex]$UnescapePatternCharacters = [regex]::new('^\\(?=[\[\\\*\?])')
            [regex]$GlobPatterns = [regex]::new('(?<!\\)\[(?<set>[^/]+)\]|(?<glob>/\*\*)|(?<star>(?<!\\)\*)|(?<any>(?<!\\)\?)|(?<text>(?:[^/?*[]|(?<=\\)[?*[])+)')
    
            [MatchEvaluator]$GlobPatternEvaluator = [MatchEvaluator]{
                param([Match]$Match)
    
In this delegate, we replace the various glob patterns with regex patterns, and escape all other text (except `/`).

                if($Match.Groups['set'].Success)
                {
                    [string]$Escaped = [regex]::Escape($Match.Groups['set'].Value)
                    if($Escaped[0] -eq '!')
                    {
                        $Escaped = '^' + $Escaped.Substring(1)
                    }
                    return "[$Escaped]"
                } elseif($Match.Groups['glob'].Success)
                {
                    return '(/.*)?'
                } elseif($Match.Groups['star'].Success)
                {
                    return '[^/]*'
                } elseif($Match.Groups['any'].Success)
                {
                    return '.'
                } else
                {
                    return [regex]::Escape($UnescapePatternCharacters.Replace($Match.Groups['text'].Value, ''))
                }
            }
    
            [LinkedList[DirectoryInfo]]$Queue = [LinkedList[DirectoryInfo]]::new()
            [LinkedList[Tuple[bool,bool,regex]]]$IgnoreRules = [LinkedList[Tuple[bool,bool,regex]]]::new()

`$IgnoreRulePerDirectoryCounts` is also used as a visited tracker. The second time a directory is seen, its added ignore rules are popped from the above list.

            [Dictionary[string,uint32]]$IgnoreRulePerDirectoryCounts = [Dictionary[string,uint32]]::new()
            [Dictionary[string,bool]]$DirectoryHasValidChildren = [Dictionary[string,bool]]::new()
            [Stack[DirectoryInfo]]$OutputDirectories = [Stack[DirectoryInfo]]::new()
            [uint32]$CurrentDepth = 0
    
            function Add-PatternRule
            {
                PARAM (
                    [Parameter(Mandatory=$true)][string]$BasePath,
                    [Parameter(Mandatory=$true)][AllowEmptyString()][string]$Pattern
                )
    
                if($CommentLine.IsMatch($Pattern))
                {
                    return 0
                }
                [bool]$IsExcludeRule = $false
                if($Pattern[0] -eq '!')
                {
                    $IsExcludeRule = $true
                    $Pattern = $Pattern.Substring(1)
                }
                # Do an initial trim/unescape/prefix/suffix
                $Pattern = $UnescapeCharacters.Replace($TrailingWhitespace.Replace($Pattern, ''), '')
                [bool]$IsDirectoryRule = $Pattern[-1] -eq '/'
                $Pattern = if($Pattern[0] -eq '/') { $Pattern } else { "/**/$Pattern" }
                $Pattern = if($IsDirectoryRule) { $Pattern } else { "$Pattern/**" }
    
                # Transform the cleaned pattern into a regex and add it to the ignore rule list
                [void]$IgnoreRules.AddFirst([Tuple[bool,bool,regex]]::new($IsExcludeRule, $IsDirectoryRule,
                        [regex]::new("^$BasePath$($GlobPatterns.Replace($Pattern, $GlobPatternEvaluator))$")))
                return 1
            }
        }

After declaring all that, we can finally get to work.

    process
        {
            $Queue.Clear()
            $IgnoreRules.Clear()
            $IgnoreRulePerDirectoryCounts.Clear()
            $DirectoryHasValidChildren.Clear()
            [void]$Queue.AddFirst([DirectoryInfo]::new((Get-Item -LiteralPath $Path.FullName).FullName.TrimEnd('\', '/')))
            [uint32]$IgnoreRuleCount = 0
            $CurrentDepth = 0
    
            [string]$BasePath = [regex]::Escape($Queue.First.Value.FullName.Replace('\', '/'))
            foreach($Pattern in $IgnorePattern)
            {
                $IgnoreRuleCount += Add-PatternRule -BasePath $BasePath -Pattern $Pattern
            }
    
            while($Queue.Count -gt 0)
            {
                [LinkedListNode[DirectoryInfo]]$NextNode = $Queue.First
                [DirectoryInfo]$Top = $NextNode.Value
                if($IgnoreRulePerDirectoryCounts.ContainsKey($Top.FullName))
                {

If this is the second time we've seen this node, remove the rules  for this directory from the list. Then, remove this directory from the map (we won't see it again, so save some memory).

                    [uint32]$IgnoreRuleCount = $IgnoreRulePerDirectoryCounts[$Top.FullName]
                    while($IgnoreRuleCount -gt 0)
                    {
                        $IgnoreRules.RemoveFirst()
                        $IgnoreRuleCount -= 1
                    }
                    [void]$IgnoreRulePerDirectoryCounts.Remove($Top.FullName)
                    $Queue.RemoveFirst()
                    $CurrentDepth -= 1
    
                    if($DirectoryHasValidChildren[$Top.FullName])
                    {

If directories are being output, push them onto a stack. Directories are re-encountered in reverse order, so they need to be re-reversed before being output.

                        $OutputDirectories.Push($Top)
                        $DirectoryHasValidChildren[$Top.Parent.FullName] = $true
                        [void]$DirectoryHasValidChildren.Remove($Top.FullName)
                    }
                    continue
                }
                $CurrentDepth += 1
                try
                {
                    # First, look for the ignore file if there is one.
                    if(![string]::IsNullOrEmpty($IgnoreFileName))
                    {
                        [FileInfo]$IgnoreFile = [FileInfo]::new([Path]::Combine($Top.FullName, $IgnoreFileName))
                        if($IgnoreFile.Exists -and !$IgnoreFile.Attributes.HasFlag([FileAttributes]::Directory))
                        {
                            try
                            {
                                # Process each line of the file as a new rule.
                                [StreamReader]$Reader = [StreamReader]::new($IgnoreFile.OpenRead())
                                [string]$BasePath = [regex]::Escape($Top.FullName.Replace('\', '/'))
                                [AllowNull()][string]$Line = $null
                                while($null -ne ($Line = $Reader.ReadLine()))
                                {
                                    $IgnoreRuleCount += Add-PatternRule -BasePath $BasePath -Pattern $Line
                                }
                            } finally
                            {

A finally block always runs, even when an exception isn't handled. This one is used to dispose of the stream reader and its underlying stream, closing the ignore file and freeing up the associated resources.

                                if($null -ne $Reader)
                                {
                                    $Reader.Close()
                                    $Reader = $null
                                }
                            }
                        }
                    }

For each directory in our stack from where we are now up to the root of the search, we keep track of how many rules were added in that directory. The next time this directory is at the front of the queue, all its children will have been processed, so we can remove the rules associated with this directory.

                    $IgnoreRulePerDirectoryCounts[$Top.FullName] = $IgnoreRuleCount
                    $IgnoreRuleCount = 0
    
Then, for each file or directory...

                    [IEnumerator[FileSystemInfo]]$Entries = $Top.EnumerateFileSystemInfos().GetEnumerator()
                    [IEnumerator[Tuple[bool,bool,regex]]]$IgnoreRule = $IgnoreRules.GetEnumerator()
                    :FilterLoop
                    while($Entries.MoveNext())
                    {
                        # .Reset() lets us re-use the same iterator over and over again
                        $IgnoreRule.Reset()
                        [FileSystemInfo]$Item = $Entries.Current
                        [bool]$IsDirectory = $Item.Attributes.HasFlag([FileAttributes]::Directory)
                        if(!$IsDirectory -and !$IncludeIgnoreFiles -and $Item.Name -eq $IgnoreFileName)
                        {

If this is an ignore file and those shouldn't be processed, skip over it.

                            continue
                        }
                        [bool]$IsHidden = $Item.Attributes.HasFlag([FileAttributes]::Hidden)
                        if(!$IsDirectory -and !$Force -and ($Hidden -ne $IsHidden))
                        {

If this is a hidden file and we're not supposed to show those, or this isn't a hidden file and $Hidden is true, then skip this item. Directories have to be searched always, in case they have hidden children but aren't hidden themselves.

                            continue
                        }
                        if($IsDirectory -and $IsHidden -and !($Force -or $Hidden))
                        {

If we aren't looking for hidden files at all and this directory is hidden, skip it.

                            continue
                        }
                        [string]$ItemName = $Item.FullName.Replace('\', '/')
                        if($IsDirectory)
                        {

All the directory-only rules match a '/' at the end of the item name; the non-directory-only rules also match the '/', but it can be not at the end.

                            $ItemName += '/'
                        }

This `do {} while($false)` structure is a GoTo. PowerShell doesn't actually have those, but sometimes they're useful, such as here, when there are a number of cases where we want to use the item handling code to either add more directories to our list or output files, and the boolean logic to determine that isn't immensely clear or straightforward.

                        :GotoLoop do {
                            # For each rule in reverse order of declaration...
                            while($IgnoreRule.MoveNext())
                            {
                                if($IgnoreRule.Current.Item2 -and !$IsDirectory)
                                {
                                    # Skip directory ignore rules for files.
                                    continue
                                }

This next bit is a bit complicated.

If the rule matched the item, and we aren't outputting ignored items, then if the rule is an allow rule and we aren't outputting ignored items, handle the item. Otherwise, if the rule didn't match the item and we are outputting ignored items, then if the rule is an ignore rule and we're outputting ignored items, handle the item.

                                if($IgnoreRule.Current.Item3.IsMatch($ItemName) -ne $Ignored)
                                {
                                    if($IgnoreRule.Current.Item1 -ne $Ignored)
                                    {
                                        # If this is an exclusion/allow rule, go to the write-out part.
                                        break GotoLoop
                                    }
                                    # Otherwise, we're done here, move on to the next item
                                    continue FilterLoop
                                }
                            }

If no rule ignored the file, and we only want to output ignored files, skip to the next item.

                            if($Ignored)
                            {
                                continue FilterLoop
                            }
                        } while($false) # End GotoLoop
                        if($IsDirectory)
                        {
                            if($CurrentDepth -le $Depth)
                            {
                                [void]$Queue.AddBefore($NextNode, [DirectoryInfo]$Item)
                            }
                        } elseif($Directory)
                        {
                            # Used by -Directory to know if it's supposed to output this one or not.
                            $DirectoryHasValidChildren[([FileInfo]$Item).DirectoryName] = $true
                        } else
                        {
                            Write-Output -InputObject ([FileInfo]$Item)
                        }
                    }
                } finally
                {

Once again, a finally block always runs. This one is used to dispose of our iterators if they still exist. In C#, this structure could be accomplished more cleanly with the `using(var entries = ...) { ... }` construction.

                    if($null -ne $Entries)
                    {
                        $Entries.Dispose()
                        $Entries = $null
                    }
                    if($null -ne $IgnoreRule)
                    {
                        $IgnoreRule.Dispose()
                        $IgnoreRule = $null
                    }
                }
            }
        }

Ha! You thought we were done! There's just one more part, if we're outputting directories instead of files. Because directories are re-visited backwards, they need to be put on a stack, and then all popped off at the end.

        end
        {
            # If there are directories to output, output them in the right order.
            while($OutputDirectories.Count -gt 0)
            {
                Write-Output -InputObject $OutputDirectories.Pop()
            }
        }
    }

---

If you're still here, all the way down at the bottom, thanks for sticking with me the whole way through that!

TL;DR: [`Get-FilteredChildItem`](https://gist.github.com/cofl/52816571c805161c75ac44dfc8634a93) emulated `.gitignore` files' patterns to arbitrarily match large file hierarchies.
