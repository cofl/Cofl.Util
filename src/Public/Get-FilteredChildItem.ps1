using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Text.RegularExpressions

<#
.SYNOPSIS
Enumerates files using .gitignore-like flat-file filters.

.DESCRIPTION
Get-FilteredChildItem uses flat-file filters to enumerate files in directory hierarchies similar to
.gitignore files. A best-effort attempt is made to be compatible with the syntax of .gitignore files,
which can be read online [here](https://git-scm.com/docs/gitignore#_pattern_format).

The use of Unix directory separators (/) is mandatory in patterns.

.EXAMPLE
PS C:\> Get-FilteredChildItem -Path $Path -IgnoreFileName .gitignore

Lists files under the directory $Path that aren't excluded by patterns declared in files with the name .gitignore.

.EXAMPLE
PS C:\> Get-FilteredChildItem -Path $Path -IgnorePattern 'pattern1', 'pattern2', 'etc'

Lists files under the directory $Path that aren't excluded by the patterns passed to the parameter IgnorePattern.

.EXAMPLE
PS C:\> Get-FilteredChildItem -Path $Path -IgnoreFileName .gitignore -Ignored

Lists files under the directory $Path that are excluded by patterns declared in files with the name .gitignore.

.EXAMPLE
PS C:\> Get-FilteredChildItem -Path $Path -IgnoreFileName .gitignore -Hidden

Lists only hidden files under the directory $Path that aren't excluded by patterns declared in files with the name
.gitignore.

.EXAMPLE
PS C:\> Get-FilteredChildItem -Path $Path -IgnoreFileName .gitignore -Force

Lists both hidden and non-hidden files under the directory $Path that aren't excluded by patterns declared in files
with the name .gitignore.

.EXAMPLE
PS C:\> Get-FilteredChildItem -Path $Path -IgnoreFileName .gitignore -Directory

Lists directories under the directory $Path that contain files that aren't excluded by patterns declared in files
with the name .gitignore.

.EXAMPLE
PS C:\> Get-FilteredChildItem -Path $Path -IgnoreFileName .gitignore -Depth 1

Lists files under the directory $Path that aren't excluded by patterns declared in files with the name .gitignore,
up to a maximum directory depth of 1 (the enumeration will include the contents of the immediate subdirectories of
the directory $Path).

.INPUTS
System.IO.DirectoryInfo The root directory to begin enumeration from.

.OUTPUTS
System.IO.FileInfo
System.IO.DirectoryInfo

.PARAMETER Path
The path to list from. Must be a directory. Accepts pipeline input.

.PARAMETER IgnoreFileName
The name of files that contain pattern rule definitions.

.PARAMETER IncludeIgnoreFiles
Include pattern rule definition files in the output unless they themselves
are ignored.

The default behavior is that they are not included in the output.

.PARAMETER IgnorePattern
Additional pattern definitions that are applied as if they were defined at the
top of a pattern rule definition file in the directory defined in Path.

.PARAMETER Directory
Emit the names of directories that are ancestors of files that would be output
by this cmdlet.

.PARAMETER Depth
Determines the number of subdirectory levels that are included in the recursion.

The default is near-infinite depth (UInt32.MaxValue).

.PARAMETER Hidden
Gets only hidden files or directories. By default, Get-FilteredChildItem gets only
non-hidden items, but you can use the Force parameter to include hidden items in
the results.

.PARAMETER Force
Gets hidden files or directories in addition to non-hidden items.

.PARAMETER Ignored
Invert all rules and only output files or directories that would have been ignored.

.LINK
https://git-scm.com/docs/gitignore#_pattern_format
#>
function Get-FilteredChildItem
{
    [CmdletBinding(DefaultParameterSetName='Default')]
    [OutputType([System.IO.FileSystemInfo])]
    PARAM (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]
            [Alias('LiteralPath')]
            [Alias('PSPath')]
            # The path to list from. Must be a directory. Accepts pipeline input.
            [DirectoryInfo]$Path,
        [Parameter()]
            [Alias('ifn')]
            # The name of the pattern rule definition files.
            [string]$IgnoreFileName,
        [Parameter()]
            [Alias('ip')]
            # A set of patterns to be applied globally from the root folder.
            # This set is added before any patterns defined in ignore files.
            [string[]]$IgnorePattern,
        [Parameter(ParameterSetName='Default')]
            # Include the ignore files in the listing, unless explicitly ignored by a filter.
            [switch]$IncludeIgnoreFiles,
        [Parameter(Mandatory=$true,ParameterSetName='Directory')]
            [Alias('ad')]
            [Alias('d')]
            # Emit the names of just the directories.
            [switch]$Directory,
        [Parameter()]
            # The depth to recurse to. Supplying a value of "0" disables recursion. The default is "infinite" depth.
            [uint32]$Depth = [uint32]::MaxValue,
        [Parameter()]
            [Alias('ah')] # like Get-ChildItem
            # Gets only hidden files or directories. By default, Get-FilteredChildItem gets only non-hidden items,
            # but you can use the Force parameter to include hidden items in the results.
            [switch]$Hidden,
        [Parameter()]
            # Gets hidden files and directories. By default, hidden items are excluded.
            [switch]$Force,
        [Parameter()]
            # Gets only ignored files or directories.
            [switch]$Ignored
    )

    begin
    {
        # Match any line that is empty, whitespace, or where the first non-whitespace character is #
        [regex]$CommentLine = [regex]::new('^\s*(?:#.*)?$')
        # Match any whitespace at the end of a line that doesn't follow a backslash
        [regex]$TrailingWhitespace = [regex]::new('(?:(?<!\\)\s)+$')
        # Match any backslash at the start of the line, or before a whitespace character.
        [regex]$UnescapeCharacters = [regex]::new('^\\|\\(?=\s)')
        # Unescape characters used in patterns
        [regex]$UnescapePatternCharacters = [regex]::new('^\\(?=[\[\\\*\?])')
        # Match glob patterns and everything that isn't one
        [regex]$GlobPatterns = [regex]::new('(?<!\\)\[(?<set>[^/]+)\]|(?<glob>/\*\*)|(?<star>(?<!\\)\*)|(?<any>(?<!\\)\?)|(?<text>(?:[^/?*[]|(?<=\\)[?*[])+)')

        # Match evaluator used to convert glob patterns/everything else into proper regex strings
        [MatchEvaluator]$GlobPatternEvaluator = [MatchEvaluator]{
            param([Match]$Match)

            # In this delegate, we replace the various glob patterns with regex patterns, and escape all other text (except /).
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
        # This dictionary is also used as a visited tracker. The second time a directory is seen, its
        # added ignore rules are popped from the above list.
        [Dictionary[string,uint32]]$IgnoreRulePerDirectoryCounts = [Dictionary[string,uint32]]::new()
        [Dictionary[string,bool]]$DirectoryHasValidChildren = [Dictionary[string,bool]]::new()
        [Stack[DirectoryInfo]]$OutputDirectories = [Stack[DirectoryInfo]]::new()
        [uint32]$CurrentDepth = 0

        # Add a rule to the rule list (or not)
        # Returns how many rules were added.
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
            [void]$IgnoreRules.AddFirst([Tuple[bool,bool,regex]]::new($IsExcludeRule, $IsDirectoryRule, [regex]::new("^$BasePath$($GlobPatterns.Replace($Pattern, $GlobPatternEvaluator))$")))
            return 1
        }
    }

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
                # If this is the second time we've seen this node, remove the rules
                # for this directory from the list. Then, remove this directory from
                # the map (we won't see it again, so save some memory).
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
                    # If directories are being output, push them onto a stack.
                    # Directories are re-encountered in reverse order, so they
                    # need to be re-reversed before being output.
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
                            # A finally block always runs.
                            # This one is used to dispose of the stream reader and its underlying stream.
                            if($null -ne $Reader)
                            {
                                $Reader.Close()
                                $Reader = $null
                            }
                        }
                    }
                }
                # For each directory in our stack from where we are now up to the root of the search,
                # we keep track of how many rules were added in that directory. The next time this
                # directory is at the front of the queue, all its children will have been processed,
                # so we can remove the rules associated with this directory.
                $IgnoreRulePerDirectoryCounts[$Top.FullName] = $IgnoreRuleCount
                $IgnoreRuleCount = 0

                # Then, for each file or directory...
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
                        # If this is an ignore file and those shouldn't be processed, skip over it.
                        continue
                    }
                    [bool]$IsHidden = $Item.Attributes.HasFlag([FileAttributes]::Hidden)
                    if(!$IsDirectory -and !$Force -and ($Hidden -ne $IsHidden))
                    {
                        # If this is a hidden file and we're not supposed to show those, or this isn't a hidden file
                        # and $Hidden is true, then skip this item.
                        # Directories have to be searched always, in case they have hidden children but aren't hidden
                        # themselves.
                        continue
                    }
                    if($IsDirectory -and $IsHidden -and !($Force -or $Hidden))
                    {
                        # If we aren't looking for hidden files at all and this directory is hidden, skip it.
                        continue
                    }
                    [string]$ItemName = $Item.FullName.Replace('\', '/')
                    if($IsDirectory)
                    {
                        # All the directory-only rules match a '/' at the end of the item name;
                        # the non-directory-only rules also match the '/', but it can be not at the end.
                        $ItemName += '/'
                    }
                    # This do {} while($false) is a GoTo. PowerShell doesn't have those,
                    # but sometimes they're useful.
                    :GotoLoop do {
                        # For each rule in reverse order of declaration...
                        while($IgnoreRule.MoveNext())
                        {
                            if($IgnoreRule.Current.Item2 -and !$IsDirectory)
                            {
                                # Skip directory ignore rules for files.
                                continue
                            }
                            # This next bit is a bit complicated.
                            # If the rule matched the item, and we aren't outputting ignored items,
                            # then if the rule is an allow rule and we aren't outputting ignored items,
                            # handle the item.
                            # Otherwise, if the rule didn't match the item and we are outputting ignored
                            # items, then if the rule is an ignore rule and we're outputting ignored items,
                            # handle the item.
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
                        # If no rule ignored the file, and we only want to output ignored files,
                        # skip to the next item.
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
                        $DirectoryHasValidChildren[([FileInfo]$Item).DirectoryName] = $true
                    } else
                    {
                        Write-Output -InputObject ([FileInfo]$Item)
                    }
                }
            } finally
            {
                # A finally block always runs.
                # This one is used to dispose of our iterators if they still exist.
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

    end
    {
        # If there are directories to output, output them in the right order.
        while($OutputDirectories.Count -gt 0)
        {
            Write-Output -InputObject $OutputDirectories.Pop()
        }
    }
}
