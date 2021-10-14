using System;
using System.Management.Automation;

namespace Cofl.Menu
{
    [Cmdlet(VerbsCommon.New, "MenuText")]
    [OutputType(typeof(HostInformationMessage))]
    public sealed class NewMenuTextCmdlet: Cmdlet
    {
        [Parameter(Mandatory = true, Position = 0, ValueFromPipeline = true)]
        public string Message { get; set ;}

        [Parameter]
        [Alias("FG")]
        public ConsoleColor? ForegroundColor { get; set; }

        [Parameter]
        [Alias("BG")]
        public ConsoleColor? BackgroundColor { get; set; }

        protected override void ProcessRecord()
        {
            WriteObject(new HostInformationMessage {
                Message = Message,
                ForegroundColor = ForegroundColor,
                BackgroundColor = BackgroundColor
            });
        }
    }
}
