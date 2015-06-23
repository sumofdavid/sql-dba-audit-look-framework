SET NUMERIC_ROUNDABORT OFF;
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON;
SET XACT_ABORT ON;

DECLARE @new_version nvarchar(100) = N'01.00.05',
        @old_version nvarchar(100) = N'01.00.04',
        @ext_version nvarchar(100);

IF NOT EXISTS(SELECT 1 FROM sys.fn_listextendedproperty(NULL,NULL,NULL,NULL,NULL,NULL,NULL) WHERE [name] = N'audit version')
    BEGIN
        RAISERROR(N'This is an upgrade script.  Run framework install script first',16,1);
    END
ELSE
    BEGIN
        SELECT @ext_version = CONVERT(nvarchar(100),value) FROM sys.fn_listextendedproperty(NULL,NULL,NULL,NULL,NULL,NULL,NULL) WHERE [name] = N'audit version';
        IF @ext_version <> @old_version
            BEGIN
                RAISERROR(N'This is the wrong upgrade script.',20,1) WITH LOG;
            END
        ELSE
            BEGIN
                EXEC sys.sp_updateextendedproperty @name = N'audit version', @value = @new_version;
            END
    END
   
PRINT 'Upgrading from version ' + @old_version + ' to ' + @new_version;
GO


IF OBJECT_ID('audit.s_KVAdd','P') IS NOT NULL
    BEGIN
        DROP PROCEDURE audit.s_KVAdd;
    END
GO
PRINT 'creating audit.s_KVAdd procedure';
GO

/*************************************************************************************************
	
	<scope>For logging</scope>
	
	<returns> 
		<return code="0"	message="Success"	type="Success" /> 
	</returns>
	
	<samples> 
		<sample>
		   <description></description>
		   <code></code> 
		</sample>
	</samples> 

	<historylog> 
		<log revision="1.0" date="05/22/2015" modifier="David Sumlin">Created</log> 
        <log revision="1.1" date="05/22/2015" modifier="David Sumlin">Added common parameters to add to KVStore</log> 
        <log revision="1.2" date="06/23/2015" modifier="David Sumlin">Added handling for invalid xml characters</log> 
	</historylog>         

**************************************************************************************************/
CREATE PROCEDURE [audit].[s_KVAdd]
(
	@session uniqueidentifier, 
	@k varchar(100),
    @v sql_variant
)
AS
SET NOCOUNT ON
SET XACT_ABORT ON

    DECLARE @tmp varchar(4000);

    IF @session IS NULL
        RAISERROR('@session can''t be NULL',16,1);

    IF @k IS NULL
        RAISERROR('@k can''t be NULL',16,1);

    SET @v = COALESCE(@v,'');

    -- this will clean up any characters which are invalid xml
    IF SQL_VARIANT_PROPERTY(@v,'BaseType') IN ('char','varchar','nchar','nvarchar')
        BEGIN
            SET @tmp = CAST(@v AS varchar(4000));
            SET @tmp = REPLACE(@tmp,'<','%lt;');
            SET @tmp = REPLACE(@tmp,'>','%gt;');
            SET @tmp = REPLACE(@tmp,'&','%amp;');
            SET @v = @tmp;
        END

	BEGIN TRY

        -- upsert
        IF EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                UPDATE audit.KVStore
                SET V = @v
                WHERE KVStoreGID = @session
                AND K = @k;
            END
        ELSE
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V)
                VALUES (@session,@k,@v);
            END

	    RETURN(0)
				
	END TRY
	BEGIN CATCH

	   BEGIN

			-- Declare local variables so we can return them to the caller			
			DECLARE @err_msg varchar(1000),
					@err_severity int;
			
			SELECT	@err_msg = ERROR_MESSAGE(),
					@err_severity = ERROR_SEVERITY();

			-- This will forcibly rollback a transaction that is marked as uncommitable
			IF (XACT_STATE()) = -1 AND @@TRANCOUNT > 0
				ROLLBACK TRANSACTION

		END

		-- Return error message to calling code via @@ERROR and error number via return code
		RAISERROR (@err_msg, @err_severity, 1)
		RETURN(ERROR_NUMBER())

	END CATCH
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Add or Update value in KVStore table' , @level0type=N'SCHEMA',@level0name=N'audit', @level1type=N'PROCEDURE',@level1name=N's_KVAdd'
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Unique session ID to identify different KV groupings in KVStore' , @level0type=N'SCHEMA',@level0name=N'audit', @level1type=N'PROCEDURE',@level1name=N's_KVAdd', @level2type=N'PARAMETER',@level2name=N'@session'
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Key' , @level0type=N'SCHEMA',@level0name=N'audit', @level1type=N'PROCEDURE',@level1name=N's_KVAdd', @level2type=N'PARAMETER',@level2name=N'@k'
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Value' , @level0type=N'SCHEMA',@level0name=N'audit', @level1type=N'PROCEDURE',@level1name=N's_KVAdd', @level2type=N'PARAMETER',@level2name=N'@v'
GO
