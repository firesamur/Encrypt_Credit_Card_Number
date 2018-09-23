# Encrypt_Credit_Card_Number
TSQL Stored Procedure which gets a ClientID and a Credit Card No by parameters, encrypts this last one with a random key and it insert or update in a table, depending wheter already exists or not.

--------------------------

## How to Decrypt the Credit Card number?
First of all, we need to have some data in the table, so we are going just to execute the Stored Procedure, passing the value **0019752834** as **ClientID** and **1111-2222-3333-4444** as **Plain_CC**.

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


--------------------------

## Certificates and Symmetric Keys
Previous point is not a bad way at all, but there are basically two big problems with it:

1. **SQL Server architecture**: Certificates and Keys are integrated in SQL Server architecture, so they are more efficient, safe and easy to use.
2. **Hard coded risks**: Also, we do not take the risk to lose the (hardcoded) string which encrypts/decrypts the data, neither to permanent losing the encrypted information.

So, let is see how to apply them. First of all, we need to create a Master Key in the DB.

```
USE [BANK_USERS_DATA] GO

CREATE MASTER KEY
ENCRYPTION BY PASSWORD = 'BUD_3ncryp710n_P4$$'
```

Once it is created, we are able to configure a self-signed certificate and install the symmetric key.

```
USE [BANK_USERS_DATA] GO

CREATE CERTIFICATE BUD_Certificate
WITH SUBJECT = 'Sensitive info related to Bank Users Data'

CREATE SYMMETRIC KEY BUDKey 
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE BUD_Certificate
```

Finally, we got it! Now we could encrypt and decrypt sensitive data just calling the certificate. How? Let me explain you.

First of all, we have this table:

```
USE [BANK_USERS_DATA] GO

CREATE TABLE [dbo].[BUD_TRANSACTIONS] (
	ID_TXN INT IDENTITY(1,1) PRIMARY KEY
	, ORIGIN_ACCOUNT VARCHAR(24) NOT NULL
	, DESTINY_ACCOUNT VARCHAR(24) NOT NULL
	, AMOUNT DECIMAL NOT NULL
	, PINCODE_TXN VARBINARY(64) NOT NULL
	, FINISHED_TXN BIT NOT NULL DEFAULT(0)
	, DATE_EXECUTED DATETIME NOT NULL DEFAULT(GETDATE())
	, DATE_FINISHED DATETIME NOT NULL DEFAULT(GETDATE())
)
```

## Insert data encrypting a column

```
USE [BANK_USERS_DATA] GO

OPEN SYMMETRIC KEY BUDKey
DECRYPTION BY CERTIFICATE BUD_Certificate

INSERT INTO [dbo].[BUD_TRANSACTIONS] ([ORIGIN_ACCOUNT],[DESTINY_ACCOUNT],[AMOUNT],[PINCODE_TXN])
VALUES (
	'IEXX01234567890123456789'
	, 'ESXX01234567890123456789'
	, 2500
	, ENCRYPTBYKEY(KEY_GUID('BUDKey'), 'P1NC0D3')
)

CLOSE SYMMETRIC KEY BUDKey;
```

As you can see, we are following these steps:

1. Open the symmetric key, decrypting it by related certificate. If you did look at the code when we created the certificate and the symmetric key, this last one was encrypted by the first one, so we need to use both of them.
2. Insert data like the common way, but calling ENCRYPTBYKEY function to do that. It needs two parameters: symmetric key to encrypt, and the value to work with. The result will be stored in table as a VARBINARY type.
3. Closing the key. If you do not do that, the server will keep it open, so resources and hardware will be used until there are so many connections we do not close and server just woulc explote like a supernova.

Yes! You did hide your sensitive information, but... Now you can see it the flat value. How can you it? Easy. Just execute a select statement (as usual), but calling function DECRYPT BY KEY. Of course, you need to open and close the symmetric key again.

```
USE [BANK_USERS_DATA] GO

OPEN SYMMETRIC KEY BUDKey
DECRYPTION BY CERTIFICATE BUD_Certificate

SELECT [ID_TXN]
	, [PINCODE_TXN]
	, CAST(DECRYPTBYKEY([PINCODE_TXN]) as varchar) as Decrypted_PINCode
	, [ORIGIN_ACCOUNT]
	, [DESTINY_ACCOUNT]
	, [AMOUNT]
	, [FINISHED_TXN]
	, [DATE_EXECUTED]
	, [DATE_FINISHED]
FROM [dbo].[BUD_TRANSACTIONS]

CLOSE SYMMETRIC KEY BUDKey;
```

And we will get:

|ID_TXN|PINCODE_TXN|Decrypted_PINCode|ORIGIN_ACCOUNT|DESTINY_ACCOUNT|AMOUNT|FINISHED_TXN|DATE_EXECUTED|DATE_FINISHED|
|------|-----------|-----------------|--------------|---------------|------|------------|-------------|-------------|
|1|0x0072C9DC4759B843B464C2F12EB49C9B020000006B3F7894F800884CDC855B50AF7641FE4C3639781B3BB60FCD8F3386E2579878|P1NC0D3|IEXX01234567890123456789|ESXX01234567890123456789|2500|0|2018-09-23 11:14:19.657|2018-09-23 11:14:19.657|

