-- TODO: add locatingFunction to Locator

-- TODO: alter Sentry to be able to remove a handler (explicitly OR implicitly if it returns something... maybe)
-- TODO: alter Sanitizer to return nil or something like that when widget gets removed (even if it then gets reinstated later)
--         OR alter Export/Import to do the removal

-- TODO: otestovat co ve Springu vrac� getfenv(0) -- ��kaj�, �e je to glob�ln� environment, ale nejsp� to bude environment funkce getfenv, co� by byl opravdu ten glob�ln�

-- IDEA: Sanitizer by mohl taky umo��ovat prozkoumat stack, ne� naraz� na prvn� widget -- d� se o�ek�vat, �e ten widget bude p�vodcem ==> ud�lat z toho funkci getCallerWidget
-- newproxy(true) um� vytvo�it userdata s novou �istou metatabulkou, newproxy(ud), kde type(ud) == "userdata", pou�ije stejnou metatabulku -- vyzkou�et, zda by t�m ne�lo p�ebrat metatabulku n��eho, co nen� proxy