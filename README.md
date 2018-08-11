# Encrypt_Credit_Card_Number
TSQL Stored Procedure which gets a ClientID and a Credit Card No by parameters, encrypts this last one with a random key and it insert or update in a table, depending wheter already exists or not.

 --------------------------

## How to Decrypt the Credit Card number?
First of all, we need to have some data in the table, so we just go to execute the Stored Procedure, passing the value **0019752834** as **ClientID** and **1111-2222-3333-4444** as **Plain_CC**.

Now, execute a ```SELECT``` with the Decrypt function:

```
SELECT [ID_CC]
	, [ID_CLIENT]
	, [CREDIT_CARD]
	, [SALT]
	, CAST(DECRYPTBYPASSPHRASE(REPLACE(SALT, '-', (select VALUE from [dbo].[MAGIC_NUMBERS] where DESCRIP = 'ENCCC')), CREDIT_CARD) as varchar) as Plain_CreditCard
	, [CREATION_DATE]
	, [UPDATED_DATE]
FROM [dbo].[CC_INFORMATION]
```

And we'll get something like this:

|ID_CC|ID_CLIENT|CREDIT_CARD|SALT|Plain_CreditCard|CREATION_DATE|UPDATED_DATE|
|-----|---------|-----------|----|----------------|-------------|------------|
|1|0019752834|0x02000000AD4C7699E60C59316A5A101A25C911504F99DFFFF74B4E3A561387E5963FABB79110C90B494B8327271268875DD3647D|0.9947271267606-400F-4331-9DCF-4CEDCA|1111-2222-3333-4444|2018-08-11 11:02:34.217|2018-08-11 11:02:34.217|

But, why we are executing a select inside of the select statement, instead of just storing the salt key in DB? Because this is a bit securler. We don't have the full key in a field, so when we want to decrypt the CC number we have the base of the key, and we just need to modify it a bit with a static value stored in another table (not in code, because of magic numbers!). Data inside of **MAGIC_NUMBERS** table (available in the ```INSERT_TABLE``` script).

|ID_MN|DESCRIP|VALUE|
|-----|-------|-----|
|1|ENCCC|$xF9.|
