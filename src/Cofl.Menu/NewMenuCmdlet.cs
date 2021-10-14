using System;
using System.Collections.Generic;
using System.Management.Automation;

namespace Cofl.Menu
{
    public enum RepeatAction {
        None,
        All,
        OnInvalidInput
    }

    public sealed class Menu: IMenuAction {
        public string Name { get; internal set; }
        public string Note { get; internal set; }
        public string[] Alias { get; internal set; }
        internal string Prompt { get; set; }
        internal RepeatAction Repeat { get; set; }
        internal List<object> Items { get; } = new List<object>();
        internal Dictionary<string, IMenuAction> Actions { get; } = new Dictionary<string, IMenuAction>(StringComparer.InvariantCultureIgnoreCase);
        internal Dictionary<string, string> AliasMap { get; } = new Dictionary<string, string>(StringComparer.InvariantCultureIgnoreCase);
    }

    public sealed class ConstantAction : IMenuAction
    {
        public string Name { get; }
        public string Note { get; } = null;
        public string[] Alias { get; } = null;

        private ConstantAction(string name){ Name = name; }
        internal static ConstantAction EXIT = new ConstantAction("EXIT");
        internal static ConstantAction RETURN = new ConstantAction("RETURN");
        internal static ConstantAction CANCEL_MENU = new ConstantAction("CANCEL_MENU");
        internal static ConstantAction CANCEL_SHARED = new ConstantAction("CANCEL_SHARED");
    }

    [Cmdlet(VerbsCommon.New, "Menu")]
    [OutputType(typeof(IMenuFunction))]
    public sealed class NewMenuCmdlet: Cmdlet
    {
        [Parameter(Mandatory = true, Position = 0)]
        public string Name { get; set; }

        [Parameter(Mandatory = true, Position = 1)]
        public object[] Items { get; set; }

        [Parameter]
        public int FirstItemNumber = 1;

        [Parameter]
        [ValidatePattern(@"(?=.*\D.*)^\S.*\S$")] // no whitespace on either side, has at least one non-digit character in it
        public string[] Alias { get; set; }

        [Parameter]
        public string Note { get; set; }

        [Parameter]
        public string Prompt { get; set; }

        [Parameter]
        public SwitchParameter NoExit { get; set; }

        [Parameter]
        public SwitchParameter AllowReturnToPrevious { get; set; }

        [Parameter]
        public SwitchParameter AllowCancelTasks { get; set; }

        [Parameter]
        public SwitchParameter AllowCancelSharedTasks { get; set; }

        [Parameter]
        public RepeatAction Repeat { get; set; } = RepeatAction.OnInvalidInput;

        protected override void ProcessRecord()
        {
            var menu = new Menu {
                Name = Name,
                Note = Note,
                Alias = Alias,
                Prompt = Prompt,
                Repeat = Repeat,
            };
            if(AllowReturnToPrevious)
            {
                menu.Actions["RETURN"] = ConstantAction.RETURN;
                menu.AliasMap["R"] = "RETURN";
                menu.AliasMap["RETURN"] = "RETURN";
            }
            if(!NoExit)
            {
                menu.Actions["QUIT"] = ConstantAction.EXIT;
                menu.AliasMap["Q"] = "QUIT";
                menu.AliasMap["QUIT"] = "QUIT";
            }
            if(AllowCancelTasks)
            {
                menu.Actions["CANCEL_MENU"] = ConstantAction.CANCEL_MENU;
                menu.AliasMap["C"] = "CANCEL_MENU";
                menu.AliasMap["CANCEL"] = "CANCEL_MENU";
            }
            if(AllowCancelSharedTasks)
            {
                menu.Actions["CANCEL_SHARED"] = ConstantAction.CANCEL_SHARED;
                menu.AliasMap["A"] = "CANCEL_SHARED";
                menu.AliasMap["CANCEL SHARED"] = "CANCEL_SHARED";
            }
            var fnNumber = FirstItemNumber;
            foreach(var _item in Items)
            {
                var item = _item is PSObject obj ? obj.BaseObject : _item;
                if(null == _item)
                    continue;
                if(item is ConstantAction)
                    continue;
                switch(item)
                {
                    case string _:
                    case HostInformationMessage _:
                        menu.Items.Add(item);
                        break;
                    case IMenuAction action:
                        var fnString = fnNumber.ToString();
                        menu.Actions[fnString] = action;
                        menu.AliasMap.Add(fnString, fnString);
                        menu.AliasMap.Add(action.Name, fnString);
                        if(null != action.Alias)
                            foreach(var alias in action.Alias)
                                menu.AliasMap.Add(alias, fnString);
                        menu.Items.Add(string.Format("  {0,4} - {1} {2}", fnString, action.Name, action.Note));
                        fnNumber += 1;
                        break;
                    default:
                        throw new ArgumentException($"Unrecognized menu item type: {item.GetType()}");
                }
            }
            if(AllowCancelTasks)
                menu.Items.Add("    [C]ancel delayed tasks");
            if(AllowCancelSharedTasks)
                menu.Items.Add("   C[a]ncel shared delayed tasks");
            if(AllowReturnToPrevious)
                menu.Items.Add("    [R]eturn to previous menu");
            if(!NoExit)
                menu.Items.Add("    [Q]uit");
            WriteObject(menu);
        }
    }
}
