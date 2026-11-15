# Routes live only in SavedVariables and travel only as export strings

Routes are stored in the account-wide SavedVariables and the addon ships with none; sharing is copy-paste of export strings (`!RK1!` + serialized + LibDeflate-compressed + print-safe encoding), which also serve as backup ("Export all"). Each Route has a random ID and a revision: importing a known ID with a higher revision offers to update, otherwise asks before overwriting, and "save as copy" is always available. The importer validates every field and never executes code from a string. Quest names are not stored; they are fetched from the game by questID so they stay localized.

## Considered Options

- Shipping the author's routes as a Lua data file built from SavedVariables by a script: rejected as unnecessary machinery; friends import the posted strings instead.
- Send-to-party over the addon channel (AceComm): deferred to a later version.
