using System.Management.Automation;

namespace Cofl.Menu
{
    public enum ExecuteOn {
        Immediate,
        MenuExit,
        AllMenuExit
    }
    internal struct DelayedTask {
        internal ExecuteOn ExecuteOn;
        internal bool OnlyOnce;
        internal ScriptBlock ScriptBlock;
    }

    [Cmdlet(VerbsCommon.New, "MenuDelayedTask")]
    [OutputType(typeof(HostInformationMessage))]
    public sealed class NewMenuDelayedTaskCmdlet: Cmdlet
    {
        [Parameter(Mandatory = true, Position = 0, ValueFromPipeline = true)]
        public ScriptBlock ScriptBlock { get; set ;}

        [Parameter]
        public ExecuteOn ExecuteOn { get; set; } = ExecuteOn.Immediate;

        [Parameter]
        public SwitchParameter OnlyOnce { get; set; }

        protected override void ProcessRecord()
        {
            WriteObject(new DelayedTask {
                ExecuteOn = ExecuteOn,
                OnlyOnce = OnlyOnce.IsPresent,
                ScriptBlock = ScriptBlock
            });
        }
    }
}
