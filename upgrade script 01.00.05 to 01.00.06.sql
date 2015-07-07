SET NUMERIC_ROUNDABORT OFF;
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON;
SET XACT_ABORT ON;

DECLARE @new_version nvarchar(100) = N'01.00.06',
        @old_version nvarchar(100) = N'01.00.05',
        @script nvarchar(100) = N'audit version',
        @ext_version nvarchar(100);

IF NOT EXISTS(SELECT 1 FROM sys.fn_listextendedproperty(NULL,NULL,NULL,NULL,NULL,NULL,NULL) WHERE [name] = @script)
    BEGIN
        RAISERROR(N'This is an upgrade script.  Run framework install script first',20,1) WITH LOG;
    END
ELSE
    BEGIN
        SELECT @ext_version = CONVERT(nvarchar(100),value) FROM sys.fn_listextendedproperty(NULL,NULL,NULL,NULL,NULL,NULL,NULL) WHERE [name] = @script;
        IF @ext_version <> @old_version
            BEGIN
                RAISERROR(N'This is the wrong upgrade script.',20,1) WITH LOG;
            END
        ELSE
            BEGIN
                EXEC sys.sp_updateextendedproperty @name = @script, @value = @new_version;
            END
    END
   
PRINT 'Upgrading from version ' + @old_version + ' to ' + @new_version;
GO


IF OBJECT_ID('audit.s_KVLog','P') IS NOT NULL
    BEGIN
        DROP PROCEDURE audit.s_KVLog;
    END
GO

PRINT 'creating audit.s_KVLog procedure';
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
        <log revision="1.2" date="05/23/2015" modifier="David Sumlin">Added better error handling and changed dates to datetime2 instead of timeoffset</log> 
        <log revision="1.3" date="07/06/2015" modifier="David Sumlin">Added attributes to XML to add data type information, also add audit framework revision</log> 
	</historylog>         

**************************************************************************************************/
CREATE PROCEDURE [Audit].[s_KVLog]
(
	@session uniqueidentifier, 
	@clear bit = 0
)
AS
SET NOCOUNT ON
SET XACT_ABORT ON

	DECLARE @err_sec varchar(128) = NULL,
            @xml xml,
            @output varchar(max),
            @k varchar(100),
            @v sql_variant,
            @db_id sql_variant,
            @obj_id sql_variant;

    -- validate input variables
    IF @session IS NULL
        RAISERROR('@session can''t be NULL',16,1);

    IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session)
        RAISERROR('@session value does not exist',16,1);

    SET @clear = COALESCE(@clear,0);

	BEGIN TRY

        SET @err_sec = 'client application name';
        SET @k = 'client_nm';
        SET @v = APP_NAME();
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END

        SET @err_sec = 'server name';
        SET @k = 'srv_nm';
        SET @v = @@SERVERNAME;
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END

        SET @err_sec = 'machine name';
        SET @k = 'mach_nm';
        SET @v = HOST_NAME();
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END

        SET @err_sec = 'user name';
        SET @k = 'usr_nm';
        SET @v = ORIGINAL_LOGIN();
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO Audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END

        SET @err_sec = 'unique id';
        SET @k = 'uid';
        SELECT @v = @session;
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END

        SET @err_sec = 'object id';
        SET @k = 'obj_id';
        SELECT @v = 0;
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END

        SET @err_sec = 'database id';
        SET @k = 'db_id';
        SELECT @v = DB_ID()
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END

        SET @err_sec = 'audit framework revision';
        SET @k = 'audit_framework_rev';
        SELECT @V = CONVERT(nvarchar(100),value) FROM sys.fn_listextendedproperty(NULL,NULL,NULL,NULL,NULL,NULL,NULL) WHERE [name] = N'audit version';
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END

        SET @err_sec = 'intermediary ids';
        SET @k = 'obj_id';
        SELECT @obj_id = V
        FROM audit.KVStore
        WHERE KVStoreGID = @session
        AND K = @k;

        SET @k = 'db_id';
        SELECT @db_id = V
        FROM audit.KVStore
        WHERE KVStoreGID = @session
        AND K = @k;

        SET @err_sec = 'database name';
        SET @k = 'db_nm';
        SET @v = COALESCE(DB_NAME(CONVERT(int,@db_id)),'');
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END
        ELSE
            BEGIN
                UPDATE audit.KVStore
                SET V = @v
                WHERE KVStoreGID = @session
                AND K = @k;
            END

        SET @err_sec = 'schema name';
        SET @k = 'sch_nm';
        SET @v = COALESCE(OBJECT_SCHEMA_NAME(CONVERT(int,@obj_id),CONVERT(int,@db_id)),'');
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END
        ELSE
            BEGIN
                UPDATE audit.KVStore
                SET V = @v
                WHERE KVStoreGID = @session
                AND K = @k;
            END

        SET @err_sec = 'object name';
        SET @k = 'obj_nm';
        SET @v = COALESCE(OBJECT_NAME(CONVERT(int,@obj_id), CONVERT(int,@db_id)),'');
        IF NOT EXISTS(SELECT 1 FROM audit.KVStore WHERE KVStoreGID = @session AND K = @k)
            BEGIN
                INSERT INTO audit.KVStore (KVStoreGID,K,V) VALUES (@session,@k,@v);
            END
        ELSE
            BEGIN
                UPDATE audit.KVStore
                SET V = @v
                WHERE KVStoreGID = @session
                AND K = @k;
            END

        SET @err_sec = 'convert to xml';
        SET @output = '<event>'

        SELECT  @output = @output + 
                    '<' + LOWER(K) + ' data_type="' + CAST(SQL_VARIANT_PROPERTY(V,'BaseType') AS varchar(128)) + '" precision="' + CAST(SQL_VARIANT_PROPERTY(V,'Precision') AS varchar(10)) + '" scale="' + CAST(SQL_VARIANT_PROPERTY(V,'Scale') AS varchar(10)) + '" MaxLength="' + CAST(SQL_VARIANT_PROPERTY(V,'MaxLength') AS varchar(10)) + '">' + 
                    CASE 
                        WHEN CAST(SQL_VARIANT_PROPERTY(V,'BaseType') AS varchar(100)) = 'datetimeoffset' THEN CONVERT(varchar(100),V,21)
                        WHEN CAST(SQL_VARIANT_PROPERTY(V,'BaseType') AS varchar(100)) = 'date' THEN CONVERT(varchar(100),V,21)
                        WHEN CAST(SQL_VARIANT_PROPERTY(V,'BaseType') AS varchar(100)) = 'datetime' THEN CONVERT(varchar(100),V,21)
                        WHEN CAST(SQL_VARIANT_PROPERTY(V,'BaseType') AS varchar(100)) = 'datetime2' THEN CONVERT(varchar(100),V,21)
                        WHEN CAST(SQL_VARIANT_PROPERTY(V,'BaseType') AS varchar(100)) = 'smalldatetime' THEN CONVERT(varchar(100),V,21)
                        WHEN CAST(SQL_VARIANT_PROPERTY(V,'BaseType') AS varchar(100)) = 'time' THEN CONVERT(varchar(100),V,21)
                        ELSE CAST(V AS varchar(MAX))
                    END + 
                    '</' + LOWER(K) + '>'
        FROM audit.KVStore
        WHERE KVStoreGID = @session;
        
        SET @output = @output + '</event>'
        
        SET @xml = TRY_CAST(@output AS xml);
        
        IF @xml IS NULL
            RAISERROR('@xml is not valid xml',16,1);

        SET @err_sec = 'log the event';
        -- ### TODO: call SB queue        
        INSERT INTO audit.EventSink (EventMessage) VALUES (@xml);

        SET @err_sec = 'delete from KVStore';
        IF @clear = 1
            BEGIN
                DELETE 
                FROM audit.KVStore
                WHERE KVStoreGID = @session;
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

			-- Log the error
            SET @output = LEFT(COALESCE(@output,''),4000);
			EXEC [audit].[s_AddSQLErrorLog] @section = @err_sec, @extrainfo = @output, @announce = 1;

		END

		-- Return error message to calling code via @@ERROR and error number via return code
		RAISERROR (@err_msg, @err_severity, 1)
		RETURN(ERROR_NUMBER())

	END CATCH
GO

EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Log the values in KVStore table to Audit Log' , @level0type=N'SCHEMA',@level0name=N'audit', @level1type=N'PROCEDURE',@level1name=N's_KVLog'
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Unique session ID to identify different KV groupings in KVStore' , @level0type=N'SCHEMA',@level0name=N'audit', @level1type=N'PROCEDURE',@level1name=N's_KVLog', @level2type=N'PARAMETER',@level2name=N'@session'
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Flag to determine whether or not to delete rows in KVStore matching @session after logging them' , @level0type=N'SCHEMA',@level0name=N'audit', @level1type=N'PROCEDURE',@level1name=N's_KVLog', @level2type=N'PARAMETER',@level2name=N'@clear'
GO