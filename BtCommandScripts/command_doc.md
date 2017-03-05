# Custom lua command implementation #

Command scripts must be created as a separate *.lua file and put in the directory "Widgets/BtCommandScripts"

Each script must contain functions "getInfo()" and "Run()". You can also define "New()" and "Reset()", but these functions make no sense for some commands and can be safely ommited.

----------

Function details
================

getInfo()
----------

- function providing details about the script

###  Implementation template ###
    
       return {
    	onNoUnits = [SUCCESS|FAILURE], -- the result of the call to Run() when no units are passed in the argument.
    	issuesOrders = boolean, -- by default false; information telling the BETS widgets if this command assigns orders to units (by Spring.GiveOrderToUnit() or similar functions)
    	parameterDefs = { -- array of the definitions of parameter that this command uses (and that the creators BTs can specify)
    		{
    			-- name of the parameter. Displayed in the BtCreator and is used to access the value in Run()
    			name = "x",
    			-- type of values that can be entered in the component 
    			variableType = ["number"|"string"|"expression"], -- expression is lua code
    			-- component to be used in BtCreator for value input. Currently only "editBox" is a valid value.
    			componentType = "editBox",
    			-- prefilled value in the component
    			defaultValue = "0",
    		},
    		{
    			name = "y",
    			variableType = "number",
    			componentType = "editBox",
    			defaultValue = "0",
    		}
    	}
    }

	
## Run(self, unitIds, parameter) ##

This function is repeatedly called until it returns SUCCESS or FAILURE.

Parameters description:
- self: instance of the command itself
- unitIds: array of IDs of the units this command is called on
- parameter: table containg the values of command parameters (the parameters that are defined in getInfo()). Values of the individual parameters can be accessed by their names, So for example `parameter.y`, which has been defined in the `getInfo()` above, is a number.

Returns: One of these predefined constants:

- `RUNNING`: Means that this function was executed successfully (meaning that for example no units got stuck), but the command is not yet done (units are not in their target position, target building was not destroyed yet,...).
- `FAILURE`: Means command is not done yet but is impossible to complete.
- `SUCCESS`: Command was successfully completed.

## New() ##
Called when the command is first instantiated. 
Use to create variables and tables that you will need in Run().

## Reset() ##
Called after Run() returns SUCCESS or FAILURE.
Use to clear the internal state of the command so it is ready to be reused.

----------

Notes for internal use only - probably not to be made public
=============================================================

## Environment ##
Commands run in the enviroment which has been defined like this:

    Command = {
    	Spring = Spring,
    	CMD = CMD,
    	VFS = VFS, -- to be removed
    	Logger = Logger,
    	dump = dump,
    	math = math,
    	select = select,
    	pairs = pairs,
    	ipairs = ipairs,
    	UnitDefNames = UnitDefNames,
    	COMMAND_DIRNAME = COMMAND_DIRNAME,
    	
    	SUCCESS = "S",
    	FAILURE = "F",
    	RUNNING = "R"
    }

If necessary (for example when you need a function/table that has not been made available in the enviroment), you can find this environment definition in Widgets/BtEvaluator/command.lua
 
