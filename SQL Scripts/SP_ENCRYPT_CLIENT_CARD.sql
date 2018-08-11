-- =============================================
-- Author:		github.com/SutterBlake
-- Create date: 2018/08/11
-- Description:	Gets a client ID and Credit Card No passed by params, 
-- encrypt this last one and INSERT or UPDATE it onto a related table.
-- =============================================

CREATE PROCEDURE [dbo].[SP_ENCRYPT_CLIENT_CARD]
	@ClientID as VARCHAR(10)
	, @Plain_CC VARCHAR(19)
AS
BEGIN
	SET NOCOUNT ON;

    -- Generates a encrypting/decrypting key and process it against the plain credit card data.
    DECLARE @enc_CreditCard as varbinary(100), @saltKey as varchar(80), @value as varchar(255) 
	set @value = (select top 1 [VALUE] from [dbo].[MAGIC_NUMBERS] where DESCRIP = 'ENCCC')
	set @saltKey = NEWID()
	set @saltKey = CAST(RAND() as varchar) + CAST(@saltKey as varchar)
    set @enc_CreditCard = EncryptByPassPhrase(REPLACE(@saltKey, '-', @value), @Plain_CC)

	-- If any of them ClientID or Plain CC passed by params are null, we just return 0 so we just can deal with it in the application.
    IF @ClientID is not null and @Plain_CC is not null
    BEGIN
        -- If client already has a CC linked, UPDATE.
        -- Note: If we want to add multiple Credit Cards associated to a same client, we will only let the INSERT statement on code below.
		IF EXISTS(SELECT TOP 1 * FROM [DEV_PRUEBAS].[dbo].[CC_INFORMATION] WHERE [ID_CLIENT] = @ClientID)
        BEGIN
            UPDATE [DEV_PRUEBAS].[dbo].[CC_INFORMATION]
            SET [CREDIT_CARD] = @enc_CreditCard
                , [SALT] = @saltKey
				, [UPDATED_DATE] = GETDATE()
            WHERE [ID_CLIENT] = @ClientID
            
            return 1
        END
        -- If does not exist, INSERT.
        ELSE
        BEGIN
            INSERT INTO [DEV_PRUEBAS].[dbo].[CC_INFORMATION] ([ID_CLIENT], [CREDIT_CARD], [SALT], [CREATION_DATE], [UPDATED_DATE]) 
            VALUES (@ClientID, @enc_CreditCard, @saltKey, GETDATE(), GETDATE())

            return 1
        END
    END
    ELSE
        return 0
END
