using System.Collections.Generic;
using System.IO;
using System.Management.Automation;
using System.Text.RegularExpressions;
using IOPath = System.IO.Path;

namespace Cofl.Util
{
    /// <summary>Enumerates files using .gitignore-like flat-file filters.</summary>
    /// <remarks>
    /// <para>
    ///    Get-FilteredChildItem uses flat-file filters to enumerate files in directory hierarchies similar to
    ///    .gitignore files. A best-effort attempt is made to be compatible with the syntax of .gitignore files,
    ///    which can be read online [here](https://git-scm.com/docs/gitignore#_pattern_format).
    /// </para>
    /// <para>
    ///    The use of Unix directory separators (/) is mandatory in patterns.
    /// </para>
    /// </remarks>
    /// <example>
    ///   <code>PS C:\> Get-FilteredChildItem -Path $Path -IgnoreFileName .gitignore</code>
    ///   <para>Lists files under the directory $Path that aren't excluded by patterns declared in files with the name .gitignore.</para>
    /// </example>
    /// <example>
    ///   <code>PS C:\> Get-FilteredChildItem -Path $Path -IgnorePattern 'pattern1', 'pattern2', 'etc'</code>
    ///   <para>Lists files under the directory $Path that aren't excluded by the patterns passed to the parameter IgnorePattern.</para>
    /// </example>
    /// <example>
    ///   <code>PS C:\> Get-FilteredChildItem -Path $Path -IgnoreFileName .gitignore -Ignored</code>
    ///   <para>Lists files under the directory $Path that are excluded by patterns declared in files with the name .gitignore.</para>
    /// </example>
    /// <example>
    ///   <code>PS C:\> Get-FilteredChildItem -Path $Path -IgnoreFileName .gitignore -Hidden</code>
    ///   <para>Lists only hidden files under the directory $Path that aren't excluded by patterns declared in files with the name .gitignore.</para>
    /// </example>
    /// <example>
    ///   <code>PS C:\> Get-FilteredChildItem -Path $Path -IgnoreFileName .gitignore -Force</code>
    ///   <para>
    ///      Lists both hidden and non-hidden files under the directory $Path that aren't excluded by patterns declared in files
    ///      with the name .gitignore.
    ///    </para>
    /// </example>
    /// <example>
    ///   <code>PS C:\> Get-FilteredChildItem -Path $Path -IgnoreFileName .gitignore -Directory</code>
    ///   <para>
    ///      Lists directories under the directory $Path that contain files that aren't excluded by patterns declared in files
    ///      with the name .gitignore.
    ///   </para>
    /// </example>
    /// <example>
    ///   <code>PS C:\> Get-FilteredChildItem -Path $Path -IgnoreFileName .gitignore -Depth 1</code>
    ///   <para>
    ///      Lists files under the directory $Path that aren't excluded by patterns declared in files with the name .gitignore,
    ///      up to a maximum directory depth of 1 (the enumeration will include the contents of the immediate subdirectories of
    ///      the directory $Path).
    ///   </para>
    /// </example>
    /// <seealso href="https://git-scm.com/docs/gitignore#_pattern_format" />
    [Cmdlet(VerbsCommon.Get, "FilteredChildItem", DefaultParameterSetName = nameof(GetFilteredChildItemCmdlet.ParameterSets.Default))]
    [OutputType(typeof(FileInfo), typeof(DirectoryInfo))]
    public sealed class GetFilteredChildItemCmdlet : Cmdlet
    {
        #region Parameters
        private enum ParameterSets
        {
            Default,
            Directory
        }

        /// <summary>
        /// The path(s) to list from. Must be a directory. Accepts pipeline input.
        /// </summary>
        [Parameter(Mandatory = true, ValueFromPipeline = true, ValueFromPipelineByPropertyName = true, Position = 0)]
        [Alias("LiteralPath", "PSPath")]
        public FileInfo[] Path { get; set; }

        /// <summary>
        /// The name of files that contain pattern rule definitions.
        /// </summary>
        [Parameter()]
        [ValidateNotNullOrEmpty]
        [Alias("ifn")]
        public string IgnoreFileName { get; set; }

        /// <summary>
        /// Additional pattern definitions that are applied as if they were defined at the
        /// top of a pattern rule definition file in the directory defined in Path.
        /// </summary>
        [Parameter()]
        public string[] IgnorePattern { get; set; }

        /// <summary>
        /// <para>Include pattern rule definition files in the output unless they themselves are ignored.</para>
        /// <para>The default behavior is that they are not included in the output.</para>
        /// </summary>
        [Parameter(ParameterSetName = nameof(ParameterSets.Default))]
        public SwitchParameter IncludeIgnoreFiles { get; set; }

        /// <summary>
        /// Emit the names of directories that are ancestors of files that would be output
        /// by this cmdlet.
        /// </summary>
        [Parameter(ParameterSetName = nameof(ParameterSets.Directory))]
        [Alias("d", "ad")]
        public SwitchParameter Directory { get; set; }

        /// <summary>
        /// <para>Determines the number of subdirectory levels that are included in the recursion.</para>
        /// <para>The default is near-infinite depth (UInt32.MaxValue).</para>
        /// </summary>
        [Parameter()]
        public uint Depth { get; set; } = uint.MaxValue;

        /// <summary>
        /// Gets only hidden files or directories. By default, Get-FilteredChildItem gets only
        /// non-hidden items, but you can use the Force parameter to include hidden items in
        /// the results.
        /// </summary>
        [Parameter()]
        [Alias("ah")]
        public SwitchParameter Hidden { get; set; }

        /// <summary>
        /// Invert all rules and only output files or directories that would have been ignored.
        /// </summary>
        [Parameter()]
        public SwitchParameter Force { get; set; }

        /// <summary>
        /// Invert all rules and only output files or directories that would have been ignored.
        /// </summary>
        [Parameter()]
        public SwitchParameter Ignored { get; set; }
        #endregion
        #region Variables
        // Match any line that is empty, whitespace, or where the first non-whitespace character is #
        private static Regex CommentLine = new Regex(@"^\s*(?:#.*)?$");

        // Match any whitespace at the end of a line that doesn't follow a backslash
        private static Regex TrailingWhitespace = new Regex(@"(?:(?<!\\)\s)+$");

        // Match any backslash at the start of the line, or before a whitespace character.
        private static Regex UnescapeCharacters = new Regex(@"^\\|\\(?=\s)");
        
        // Unescape characters used in patterns
        private static Regex UnescapePatternCharacters = new Regex(@"^\\(?=[\[\\\*\?])");
        
        // Match glob patterns and everything that isn't one
        private static Regex GlobPatterns = new Regex(string.Join("|", $@"(?<!\\)\[(?<{SetGroup}>[^/]+)\]",
                                                                $@"(?<{GlobGroup}>/\*\*)",
                                                                $@"(?<{StarGroup}>(?<!\\)\*)",
                                                                $@"(?<{AnyGroup}>(?<!\\)\?)",
                                                                $@"(?<{TextGroup}>(?:[^/?*[]|(?<=\\)[?*[])+)"));
        
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
        private LinkedList<DirectoryInfo> Queue = new LinkedList<DirectoryInfo>();
        private LinkedList<IgnoreRule> IgnoreRules = new LinkedList<IgnoreRule>();
        private Dictionary<string, bool> DirectoryHasValidChildren = new Dictionary<string, bool>();
        private Stack<DirectoryInfo> OutputDirectories = new Stack<DirectoryInfo>();

        // This dictionary is also used as a visited tracker. The second time a directory is seen, its
        // added ignore rules are popped from the above list.
        private Dictionary<string, uint> IgnoreRulePerDirectoryCounts = new Dictionary<string, uint>();

        private const string SetGroup = "Set";
        private const string GlobGroup = "Glob";
        private const string StarGroup = "Star";
        private const string AnyGroup = "Any";
        private const string TextGroup = "Text";

        /// <summary>Match evaluator used to convert glob patterns/everything else into proper regex strings</summary>
        private static string GlobPatternEvaluator(Match match)
        {
            // In this delegate, we replace the various glob patterns with regex patterns, and escape all other text (except /).
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
        #endregion
        
        protected override void ProcessRecord()
        {
            foreach(var path in Path)
            {
                IgnoreRules.Clear();
                // If the current path is a file, handle it in a special way.
                if(!path.Attributes.HasFlag(FileAttributes.Directory))
                {
                    // skip out early if the file is an ignore file and those aren't included.
                    if(path.Name == IgnoreFileName && !IncludeIgnoreFiles)
                        continue;
                    AddIgnorePatterns(((FileInfo) path).DirectoryName.Replace('\\', '/'));
                    ProcessFileSystemItem(path, 0, null);

                    // then, skip ahead to write out any directories for this item, and continue.
                    goto WriteDirectories;
                }

                // otherwise, clean up for the next run
                Queue.Clear();
                IgnoreRulePerDirectoryCounts.Clear();
                DirectoryHasValidChildren.Clear();
                
                // add the next item and begin.
                Queue.AddFirst(new DirectoryInfo(path.FullName.TrimEnd('/', '\\')));
                
                uint currentDepth = 0;
                var ignoreRuleCount = AddIgnorePatterns(Regex.Escape(Queue.First.Value.FullName.Replace('\\', '/')));;
                while(Queue.Count > 0)
                {
                    var nextNode = Queue.First;
                    var top = nextNode.Value;

                    if(IgnoreRulePerDirectoryCounts.ContainsKey(top.FullName))
                    {
                        // If this is the second time we've seen this node, remove the rules
                        // for this directory from the list. Then, remove this directory from
                        // the map (we won't see it again, so save some memory).
                        ignoreRuleCount = IgnoreRulePerDirectoryCounts[top.FullName];
                        for(; ignoreRuleCount > 0; ignoreRuleCount -= 1)
                            IgnoreRules.RemoveFirst();
                        IgnoreRulePerDirectoryCounts.Remove(top.FullName);
                        Queue.RemoveFirst();
                        currentDepth -= 1;

                        if(DirectoryHasValidChildren.ContainsKey(top.FullName))
                        {
                            // If directories are being output, push them onto a stack.
                            // Directories are re-encountered in reverse order, so they
                            // need to be re-reversed before being output.
                            OutputDirectories.Push(top);
                            DirectoryHasValidChildren[top.Parent.FullName] = true;
                            DirectoryHasValidChildren.Remove(top.FullName);
                        }
                        continue;
                    }

                    currentDepth += 1;
                    
                    // First, look for the ignore file if there is one.
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

                    // For each directory in our stack from where we are now up to the root of the search,
                    // we keep track of how many rules were added in that directory. The next time this
                    // directory is at the front of the queue, all its children will have been processed,
                    // so we can remove the rules associated with this directory.
                    IgnoreRulePerDirectoryCounts[top.FullName] = ignoreRuleCount;
                    ignoreRuleCount = 0;

                    // Then, for each file or directory...
                    using(var entries = top.EnumerateFileSystemInfos().GetEnumerator())
                    while(entries.MoveNext())
                        ProcessFileSystemItem(entries.Current, currentDepth, nextNode);
                }

                WriteDirectories:
                // If there are directories to output, output them in the right order.
                while(OutputDirectories.Count > 0)
                    WriteObject(OutputDirectories.Pop());
            }
        }

        private uint AddIgnorePatterns(string basePath)
        {
            uint counter = 0;
            if(IgnorePattern != null)
                foreach(var pattern in IgnorePattern)
                    counter += AddPatternRule(basePath, pattern);
            return counter;
        }

        private void ProcessFileSystemItem(FileSystemInfo item, uint currentDepth, LinkedListNode<DirectoryInfo> nextNode)
        {
            var isDirectory = item.Attributes.HasFlag(FileAttributes.Directory);
            // If this is an ignore file and those shouldn't be processed, skip over it.
            if(!isDirectory && !IncludeIgnoreFiles && item.Name == IgnoreFileName)
                return;
            var isHidden = item.Attributes.HasFlag(FileAttributes.Hidden);
            // If this is a hidden file and we're not supposed to show those, or this isn't a hidden file
            // and $Hidden is true, then skip this item.
            // Directories have to be searched always, in case they have hidden children but aren't hidden
            // themselves.
            if(!isDirectory && !Force && (Hidden != isHidden))
                return;
            // If we aren't looking for hidden files at all and this directory is hidden, skip it.
            if(isDirectory && isHidden && !(Force || Hidden))
                return;
            var itemName = item.FullName.Replace('\\', '/');
            // All the directory-only rules match a '/' at the end of the item name;
            // the non-directory-only rules also match the '/', but it can be not at the end.
            if(isDirectory)
                itemName += '/';
            // For each rule in reverse order of declaration...
            foreach(var rule in IgnoreRules)
            {
                // Skip directory ignore rules for files.
                if(rule.IsDirectoryRule && !isDirectory)
                    continue;
                // This next bit is a bit complicated.
                // If the rule matched the item, and we aren't outputting ignored items,
                // then if the rule is an allow rule and we aren't outputting ignored items,
                // handle the item.
                // Otherwise, if the rule didn't match the item and we are outputting ignored
                // items, then if the rule is an ignore rule and we're outputting ignored items,
                // handle the item.
                if(rule.Pattern.IsMatch(itemName) != Ignored.IsPresent)
                {
                    // If this is an exclusion/allow rule, go to the write-out part.
                    if(rule.IsExcludeRule != Ignored)
                        goto Output;
                    // Otherwise, we're done here
                    return;
                }
            }

            // If no rule ignored the file, and we only want to output ignored files,
            // skip to the next item.
            if(Ignored)
                return;

            Output:
            if(isDirectory)
            {
                if(currentDepth <= Depth)
                    Queue.AddBefore(nextNode, (DirectoryInfo) item);
            } else if(Directory)
            {
                DirectoryHasValidChildren[((FileInfo) item).DirectoryName] = true;
            } else
            {
                WriteObject((FileInfo) item);
            }
        }
    }
}
