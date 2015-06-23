SET NUMERIC_ROUNDABORT OFF;
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON;
SET XACT_ABORT ON;

DECLARE @new_version nvarchar(100) = N'01.00.04',
        @old_version nvarchar(100) = N'01.00.03',
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
                RAISERROR(N'This is the wrong upgrade script.',16,1);
            END
        ELSE
            BEGIN
                EXEC sys.sp_updateextendedproperty @name = N'audit version', @value = @new_version;
            END
    END
   
PRINT 'Upgrading from version ' + @old_version + ' to ' + @new_version;
GO


IF OBJECT_ID('audit.s_AddSQLErrorLog','P') IS NOT NULL
    BEGIN
        DROP PROCEDURE audit.s_AddSQLErrorLog;
    END
GO
PRINT 'creating audit.s_AddSQLErrorLog procedure';
GO

/*************************************************************************************************
	<returns> 
			<return value="0" description="Success"/> 
	</returns>
	
	<samples> 
		<sample>
			<description>This procedure logs sql errors from scripts or procedures and puts them into the EventSink
			</description>
			<code>EXEC [audit].[s_AddSQLErrorLog] 'Sample section in code'</code> 
		</sample>
	</samples> 
	
	<historylog> 
		<log revision="1.0" date="05/01/2010" modifier="David Sumlin">Created</log> 
		<log revision="1.1" date="06/05/2010" modifier="David Sumlin">Added @extrainfo parameter</log> 
		<log revision="1.2" date="06/29/2010" modifier="David Sumlin">Added @announce parameter</log> 		
		<log revision="1.3" date="09/03/2010" modifier="David Sumlin">Added WITH EXECUTE AS OWNER.  This allows me to grant EXEC permissions on this proc without the table</log> 
		<log revision="1.4" date="11/30/2011" modifier="David Sumlin">Added @alt variable for flexibility.  Initially created to remove INSERT...EXEC functionality so proc can be used in other INSERT...EXEC scenarios</log> 
		<log revision="1.5" date="11/30/2012" modifier="David Sumlin">Changed to use DBA schema in local database</log> 
        <log revision="1.6" date="06/12/2015" modifier="David Sumlin">Changed to use Audit.EventSink and changed schema to Audit</log> 
        <log revision="1.7" date="06/16/2015" modifier="David Sumlin">Added err_dt to log event</log> 
        <log revision="1.8" date="06/22/2015" modifier="David Sumlin">Added feature info to log event</log> 
	</historylog>         
	
**************************************************************************************************/
CREATE PROCEDURE [audit].[s_AddSQLErrorLog]
(
	@section varchar(128) = NULL,
	@extrainfo nvarchar(4000) = NULL,
	@announce int = 1,
	@alt varchar(100) = NULL
)
WITH EXECUTE AS OWNER
AS
SET NOCOUNT ON
 
	DECLARE @cmd varchar(1000),
            @xml xml,
            @event_info nvarchar(4000),
            @event_type nvarchar(30);
	
	-- use this table to hold the info from DBCC INPUTBUFFER
	DECLARE @err_tbl table 
		(
			[EventType] nvarchar(30) NULL, 
			[Parameters] int NULL, 
			[EventInfo] nvarchar(4000) NULL
		)

	IF @alt = 'NO INSERT EXEC'
		BEGIN
			INSERT INTO @err_tbl (EventInfo) VALUES (@alt)
		END
	ELSE
		BEGIN	
			-- We're calling this to get the code that was originally executing
			SET @cmd = 'DBCC INPUTBUFFER( ' + CAST(@@spid as varchar) + ') WITH NO_INFOMSGS'

			INSERT INTO @err_tbl 
			EXEC(@cmd)
		END

    SELECT 
        @event_info = [EventInfo],
        @event_type = [EventType]
    FROM @err_tbl;

	SET @xml = 
    (
    SELECT
        'error' AS evt_type,
        'alert' AS evt_status,
        SYSUTCDATETIME() AS err_dt,
        COALESCE(@announce,'') AS err_announce,
        'deprecated: Procedure should not be used, use KV framework.' AS feature_info, 
        COALESCE(@@SPID,'')  AS err_spid,
        COALESCE(ERROR_PROCEDURE(),'') AS err_proc_nm,
        COALESCE(ERROR_LINE(),'') AS err_line,
        COALESCE(ERROR_NUMBER(),'') AS err_num,
        COALESCE(ERROR_MESSAGE(),'') AS err_msg,
        COALESCE(ERROR_SEVERITY(),'') AS err_lvl,
        COALESCE(ERROR_STATE(),'') AS err_state,
        COALESCE(@@SERVERNAME,'') AS srv_nm,
        COALESCE(DB_NAME(),'') AS db_nm,
		COALESCE(@section,'') AS sec_nm,
		COALESCE(@event_info,'') AS evt_txt,
		COALESCE(@event_type,'') AS evt_info,
        COALESCE(HOST_NAME(),'') AS mach_nm,
        COALESCE(ORIGINAL_LOGIN(),'') AS usr_nm
        FOR XML RAW ('event'), ELEMENTS
    );

    -- Log it
    INSERT INTO audit.EventSink (EventMessage) VALUES (@xml)

GO
