using System;
using System.Collections.Generic;
using System.Management.Automation;

namespace Cofl.Menu
{

    [Cmdlet(VerbsLifecycle.Invoke, "Menu")]
    public sealed class InvokeMenuCmdlet: PSCmdlet
    {
        [Parameter(Mandatory = true, Position = 0, ValueFromPipeline = true)]
        public Menu Menu { get; set; }

        [Parameter]
        public SwitchParameter PreventInterrupt { get; set; }

        private bool OriginalInterruptValue;
        private static string[] InfoTags = new[]{ "PSHOST", "Menu" };

        protected override void BeginProcessing()
        {
            if(PreventInterrupt)
            {
                OriginalInterruptValue = Console.TreatControlCAsInput;
                Console.TreatControlCAsInput = PreventInterrupt;
            }
        }
        protected override void ProcessRecord()
        {
            var intSelection = -1;
            var menuStack = new Stack<(Menu menu, Queue<ScriptBlock> delayedTasks)>();
            var sharedDelayedTasks = new Queue<ScriptBlock>();
            menuStack.Push((Menu, new Queue<ScriptBlock>()));
            var exitMenu = false;
            
            menus:
            while(menuStack.Count > 0)
            {
                var (menu, delayedTasks) = menuStack.Peek();
                if(!exitMenu)
                {
                    bool repeat;
                    do {
                        repeat = menu.Repeat != RepeatAction.None;
                        foreach(var item in menu.Items)
                            WriteInformation(item, InfoTags);
                        Console.Write(menu.Prompt ?? "Option: ");
                        var selection = Console.ReadLine();
                        if(int.TryParse(selection, out intSelection))
                            selection = intSelection.ToString();
                        if(!menu.AliasMap.ContainsKey(selection))
                        {
                            if(menu.Repeat != RepeatAction.None)
                            {
                                WriteWarning($"Invalid selection: \"{selection}\". Please provide a valid input.");
                                repeat = true;
                                continue;
                            } else
                            {
                                throw new ArgumentException($"Invalid selection: \"{selection}\".");
                            }
                        }
                        switch(menu.Actions[menu.AliasMap[selection]])
                        {
                            case ConstantAction constantAction:
                                if(constantAction == ConstantAction.EXIT)
                                {
                                    exitMenu = true;
                                    goto breakInputLoop;
                                } else if(constantAction == ConstantAction.RETURN)
                                {
                                    goto breakInputLoop;
                                }
                                break;
                            case Menu submenu:
                                menuStack.Push((submenu, new Queue<ScriptBlock>()));
                                goto menus;
                            case IMenuFunction fn:
                                var tasks = new Queue<ScriptBlock>();
                                foreach(var outputItem in fn.Invoke(null, null))
                                {
                                    if(outputItem.BaseObject is DelayedTask task)
                                    {
                                        switch(task.ExecuteOn)
                                        {
                                            case ExecuteOn.Immediate:
                                                if(!task.OnlyOnce || !tasks.Contains(task.ScriptBlock))
                                                    tasks.Enqueue(task.ScriptBlock);
                                                break;
                                            case ExecuteOn.MenuExit:
                                                if(!task.OnlyOnce || !delayedTasks.Contains(task.ScriptBlock))
                                                    delayedTasks.Enqueue(task.ScriptBlock);
                                                break;
                                            case ExecuteOn.AllMenuExit:
                                                if(!task.OnlyOnce || !sharedDelayedTasks.Contains(task.ScriptBlock))
                                                    sharedDelayedTasks.Enqueue(task.ScriptBlock);
                                                break;
                                        }
                                    } else
                                    {
                                        WriteObject(outputItem, false);
                                    }
                                }
                                while(tasks.Count > 0)
                                    foreach(var obj in tasks.Dequeue().Invoke())
                                        WriteObject(obj, false);
                                switch(fn.FunctionExitBehavior){
                                    case FunctionExitBehavior.BreakMenu:
                                        goto breakInputLoop;
                                    case FunctionExitBehavior.QuitAll:
                                        exitMenu = true;
                                        goto breakInputLoop;
                                    case FunctionExitBehavior.None:
                                        break;
                                }
                                break;
                            default:
                                break;
                        }
                    } while(repeat);
                    breakInputLoop:;
                }
                while(delayedTasks.Count > 0)
                    foreach(var obj in delayedTasks.Dequeue().Invoke())
                        WriteObject(obj, false);
                menuStack.Pop();
            }
            while(sharedDelayedTasks.Count > 0)
                foreach(var obj in sharedDelayedTasks.Dequeue().Invoke())
                    WriteObject(obj, false);
        }

        protected override void EndProcessing()
        {
            if(PreventInterrupt)
                Console.TreatControlCAsInput = OriginalInterruptValue;
        }
    }
}
