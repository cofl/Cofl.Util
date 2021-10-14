using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Management.Automation;

namespace Cofl.Menu
{
    internal class Context {
        internal List<PSVariable> AsVariableList { get; private set; }
        internal Context()
        {
            AsVariableList = new List<PSVariable> { new PSVariable("context", this) };
        }
    }
    internal interface IMenuAction
    {
        string Name { get; }
        string Note { get; }
        string[] Alias { get; }
    }

    public enum FunctionExitBehavior
    {
        None,
        BreakMenu,
        QuitAll
    }

    internal interface IMenuFunction: IMenuAction
    {
        FunctionExitBehavior FunctionExitBehavior { get; }
        Collection<PSObject> Invoke(Dictionary<string, ScriptBlock> fns, Context context);
    }

    internal sealed class ScriptBlockMenuFunction: IMenuFunction
    {
        public string Name { get; internal set; }
        public string Note { get; internal set; }
        public string[] Alias { get; internal set; }
        public FunctionExitBehavior FunctionExitBehavior { get; internal set; }
        internal ScriptBlock ScriptBlock { get; set; }
        public Collection<PSObject> Invoke(Dictionary<string, ScriptBlock> fns, Context context)
            => ScriptBlock.Invoke();
    }

    internal sealed class CommandInfoMenuFunction: IMenuFunction
    {
        private static ScriptBlock ExecutingScriptBlock = ScriptBlock.Create("param($Object) & $Object");
        public string Name => CommandInfo.Name;
        public string Note { get; internal set; }
        public string[] Alias { get; internal set; }
        public FunctionExitBehavior FunctionExitBehavior { get; internal set; }
        internal CommandInfo CommandInfo { get; set; }
        public Collection<PSObject> Invoke(Dictionary<string, ScriptBlock> fns, Context context)
            => ExecutingScriptBlock.Invoke(CommandInfo);
    }

    [Cmdlet(VerbsCommon.New, "MenuFunction", DefaultParameterSetName = "Name")]
    [OutputType(typeof(IMenuFunction))]
    public sealed class NewMenuFunctionCmdlet: Cmdlet
    {
        private static ScriptBlock LookUpFunctionInfo = ScriptBlock.Create("param($Name) Get-Item $Name -ErrorAction SilentlyContinue");
        [Parameter(Mandatory = true, Position = 0, ParameterSetName = "Name")]
        [Parameter(Mandatory = true, Position = 0, ParameterSetName = "Script")]
        public string Name { get; set; }

        [Parameter(Mandatory =true, Position = 0, ParameterSetName = "CommandInfo")]
        public CommandInfo FunctionInfo { get; set; }

        [Parameter(Mandatory = true, Position = 1, ParameterSetName = "Script")]
        public ScriptBlock ScriptBlock { get; set; }

        [Parameter]
        [ValidatePattern(@"(?=.*\D.*)^\S.*\S$")] // no whitespace on either side, has at least one non-digit character in it
        public string[] Alias { get; set; }

        [Parameter]
        public string Note { get; set; }

        [Parameter]
        public FunctionExitBehavior OnExit { get; set; }

        protected override void ProcessRecord()
        {
            if(null != ScriptBlock)
            {
                WriteObject(new ScriptBlockMenuFunction
                {
                    Name = Name,
                    Alias = Alias,
                    Note = Note,
                    ScriptBlock = ScriptBlock
                });
            } else
            {
                if(!string.IsNullOrEmpty(Name))
                {
                    var fn = LookUpFunctionInfo.Invoke(Name).First();
                    if(fn.BaseObject is FunctionInfo fi)
                    {
                        WriteObject(new ScriptBlockMenuFunction
                        {
                            Name = fi.Name,
                            Alias = Alias,
                            Note = Note,
                            FunctionExitBehavior = OnExit,
                            ScriptBlock = fi.ScriptBlock,
                        });
                    } else if(fn.BaseObject is CommandInfo info)
                    {
                        WriteObject(new CommandInfoMenuFunction
                        {
                            CommandInfo = info,
                            Alias = Alias,
                            Note = Note,
                            FunctionExitBehavior = OnExit,
                        });
                    } else {
                        throw new ArgumentException($"Unrecognized command type for name lookup: {Name}");
                    }
                }
            }
        }
    }
}
