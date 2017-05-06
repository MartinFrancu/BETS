-- TODO: add locatingFunction to Locator

-- TODO: alter Sentry to be able to remove a handler (explicitly OR implicitly if it returns something... maybe)
-- TODO: alter Sanitizer to return nil or something like that when widget gets removed (even if it then gets reinstated later)
--         OR alter Export/Import to do the removal

-- TODO: otestovat co ve Springu vrací getfenv(0) -- øíkají, že je to globální environment, ale nejspíš to bude environment funkce getfenv, což by byl opravdu ten globální

-- IDEA: Sanitizer by mohl taky umožòovat prozkoumat stack, než narazí na první widget -- dá se oèekávat, že ten widget bude pùvodcem ==> udìlat z toho funkci getCallerWidget
-- newproxy(true) umí vytvoøit userdata s novou èistou metatabulkou, newproxy(ud), kde type(ud) == "userdata", použije stejnou metatabulku -- vyzkoušet, zda by tím nešlo pøebrat metatabulku nìèeho, co není proxy