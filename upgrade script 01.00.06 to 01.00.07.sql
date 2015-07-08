SET NUMERIC_ROUNDABORT OFF;
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON;
SET XACT_ABORT ON;

DECLARE @new_version nvarchar(100) = N'01.00.07',
        @old_version nvarchar(100) = N'01.00.06',
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
        <log revision="1.9" date="07/08/2015" modifier="David Sumlin">Changed to use KVLog functionality</log>
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

    DECLARE @db_nm sysname = DB_NAME(),
            @mach_nm sysname = HOST_NAME(),
            @usr_nm sysname = ORIGINAL_LOGIN(),
            @err_dt datetime2(7) = SYSUTCDATETIME(),
            @err_proc_nm sysname = ERROR_PROCEDURE(),
            @err_line int = ERROR_LINE(),
            @err_num int = ERROR_NUMBER(),
            @err_msg nvarchar(4000) = ERROR_MESSAGE(),
            @err_lvl int = ERROR_SEVERITY(),
            @err_state int = ERROR_STATE(),
            @version uniqueidentifier = NEWID()
    

    SET @announce = COALESCE(@announce,'');
    
    -- log new style
    EXEC audit.s_KVAdd @version, 'evt_type', 'error';
    EXEC audit.s_KVAdd @version, 'evt_status', 'alert';
    EXEC audit.s_KVAdd @version, 'err_dt', @err_dt;
    EXEC audit.s_KVAdd @version, 'err_announce', @announce;
    EXEC audit.s_KVAdd @version, 'feature_info', 'deprecated: Procedure should not be used, use KV framework.';
    EXEC audit.s_KVAdd @version, 'err_spid', @@SPID;    
    EXEC audit.s_KVAdd @version, 'err_proc_nm', @err_proc_nm;    
    EXEC audit.s_KVAdd @version, 'err_line', @err_line;    
    EXEC audit.s_KVAdd @version, 'err_num', @err_num;    
    EXEC audit.s_KVAdd @version, 'err_msg', @err_msg;    
    EXEC audit.s_KVAdd @version, 'err_lvl', @err_lvl;    
    EXEC audit.s_KVAdd @version, 'err_state', @err_state;    
    EXEC audit.s_KVAdd @version, 'srv_nm', @@SERVERNAME;
    EXEC audit.s_KVAdd @version, 'db_nm', @db_nm;
    EXEC audit.s_KVAdd @version, 'uid', @version;
    EXEC audit.s_KVAdd @version, 'sec_nm', @section;
    EXEC audit.s_KVAdd @version, 'evt_txt', @event_info;
    EXEC audit.s_KVAdd @version, 'evt_info', @event_type;
    EXEC audit.s_KVAdd @version, 'mach_nm', @mach_nm;
    EXEC audit.s_KVAdd @version, 'usr_nm', @usr_nm;
    EXEC audit.s_KVAdd @version, 'alt_msg', @alt;
    EXEC audit.s_KVLog @version, 1;

GO

IF OBJECT_ID('audit.s_AddProcExecLog','P') IS NOT NULL
    BEGIN
        DROP PROCEDURE audit.s_AddProcExecLog;
    END
GO
PRINT 'creating audit.s_AddProcExecLog procedure';
GO

/*************************************************************************************************
	<returns> 
			<return value="0" description="Success"/> 
	</returns>

	<samples> 
		<sample>
			<description>
			This would insert stored procedure execution values into the [Audit].[EventSink] table.
			</description>
			<code>EXEC [audit].[s_AddProcExecLog] DB_ID(), @@PROCID, @exec_start, @exec_end, NULL, NULL, NULL, NULL</code> 
		</sample>
	</samples> 

	<historylog> 
		<log revision="1.0" date="05/01/2010" modifier="David Sumlin">Created</log> 
		<log revision="1.1" date="05/26/2010" modifier="David Sumlin">Added @rows parameter to accomodate new columns in Log_ProcExec table</log> 		
		<log revision="1.2" date="05/26/2010" modifier="David Sumlin">Added @section and @version parameters to accomodate new columns in Log_ProcExec table</log> 		
		<log revision="1.3" date="05/26/2010" modifier="David Sumlin">Changed schema to Audit</log> 		
		<log revision="1.4" date="06/01/2010" modifier="David Sumlin">Added ISNULL check for @version variable</log> 				
		<log revision="1.5" date="06/05/2010" modifier="David Sumlin">Added @db_id variable to determine proc name from different databases</log> 				
		<log revision="1.6" date="06/08/2010" modifier="David Sumlin">Added ISNULL check for @object_id, @db_id variables</log> 						
		<log revision="1.7" date="07/29/2010" modifier="David Sumlin">Fixed @db_id variable insertion.  For some reason I was always inserting the id for the DBA database.</log> 								
		<log revision="1.8" date="09/03/2010" modifier="David Sumlin">Added WITH EXECUTE AS OWNER.  This allows me to grant EXEC permissions on this proc without the table</log> 
		<log revision="1.9" date="11/30/2011" modifier="David Sumlin">Added @alt variable for flexibility.  Initially created to remove INSERT...EXEC functionality so proc can be used in other INSERT...EXEC scenarios</log> 
		<log revision="2.0" date="11/30/2012" modifier="David Sumlin">Changed to DBA schema for local database</log>
		<log revision="2.1" date="06/12/2014" modifier="David Sumlin">Changed datetime2 to datetimeoffset</log> 
        <log revision="2.2" date="12/03/2014" modifier="David Sumlin">Added @object_nm for adhoc code that is not in a stored procedure</log> 
        <log revision="2.3" date="12/17/2014" modifier="David Sumlin">Added (7) to datetimeoffset input parameters</log> 
        <log revision="2.4" date="04/06/2015" modifier="David Sumlin">Change from inserting rows into Audit.ProcExecLog into inserting xml into Audit.EventSink.  Also added @app_nm parameter</log>
        <log revision="2.5" date="04/06/2015" modifier="David Sumlin">Removed WITH EXECUTE AS OWNER.  Was incorrect in my previous understanding.  Permission should be a schema level.</log>
        <log revision="2.6" date="06/12/2015" modifier="David Sumlin">Changed to audit schema</log>
        <log revision="2.7" date="06/22/2015" modifier="David Sumlin">Added deprecated feature</log>
        <log revision="2.8" date="07/08/2015" modifier="David Sumlin">Changed to use KVLog functionality</log>
	</historylog>         

**************************************************************************************************/
CREATE PROCEDURE [audit].[s_AddProcExecLog]
(
	@db_id int,
	@object_id int,
	@start datetimeoffset(7) = NULL,
	@end datetimeoffset(7) = NULL,
	@extra_info nvarchar(2000) = NULL,
	@rows int = NULL,
	@section varchar(300) = NULL,
	@version uniqueidentifier = NULL,
	@alt varchar(100) = NULL,
    @object_nm nvarchar(128) = NULL,
    @app_nm nvarchar(128) = NULL
)
AS
SET NOCOUNT ON

	DECLARE @cmd varchar(1000),
            @xml xml,
            @event_info nvarchar(4000);

	-- use this table to hold the info from DBCC INPUTBUFFER or anything else
	DECLARE @dbcc_tbl table 
		(
			[EventType] nvarchar(30) NULL, 
			[Parameters] int NULL, 
			[EventInfo] nvarchar(4000) NULL
		)

	IF @alt = 'NO INSERT EXEC'
		BEGIN
			INSERT INTO @dbcc_tbl (EventInfo) VALUES (@alt)
		END
	ELSE
		BEGIN	
			-- We're calling this to get the code that was originally executing
			SET @cmd = 'DBCC INPUTBUFFER( ' + CAST(@@spid as varchar) + ') WITH NO_INFOMSGS'

			INSERT INTO @dbcc_tbl 
			EXEC(@cmd)
		END
		
    SELECT 
        @event_info = [EventInfo] 
    FROM @dbcc_tbl;


    DECLARE @db_nm sysname = DB_NAME(@db_id),
            @sch_nm sysname = OBJECT_SCHEMA_NAME(@object_id, @db_id),
            @obj_nm sysname = COALESCE(OBJECT_NAME(@object_id, @db_id),COALESCE(@object_nm,'unknown')),
            @mach_nm sysname = HOST_NAME(),
            @usr_nm sysname = ORIGINAL_LOGIN();
    
    SET @db_id = COALESCE(@db_id,0);
    SET @version = COALESCE(@version,NEWID());
    SET @object_id = COALESCE(@object_id,0);

    -- log new style
    EXEC audit.s_KVAdd @version, 'evt_type', 'proc exec';
    EXEC audit.s_KVAdd @version, 'evt_status', 'info';
    EXEC audit.s_KVAdd @version, 'app_nm', @app_nm;    
    EXEC audit.s_KVAdd @version, 'srv_nm', @@SERVERNAME;
    EXEC audit.s_KVAdd @version, 'feature_info', 'deprecated: Procedure should not be used, use KV framework.';
    EXEC audit.s_KVAdd @version, 'db_nm', @db_nm;
    EXEC audit.s_KVAdd @version, 'sch_nm', @sch_nm;    
    EXEC audit.s_KVAdd @version, 'bgn_dt', @start;
    EXEC audit.s_KVAdd @version, 'end_dt', @end;
    EXEC audit.s_KVAdd @version, 'db_id', @db_id;
    EXEC audit.s_KVAdd @version, 'uid', @version;
    EXEC audit.s_KVAdd @version, 'obj_id', @object_id;
    EXEC audit.s_KVAdd @version, 'obj_nm', @obj_nm;
    EXEC audit.s_KVAdd @version, 'sec_nm', @section;
    EXEC audit.s_KVAdd @version, 'evt_txt', @event_info;
    EXEC audit.s_KVAdd @version, 'evt_info', @extra_info;
    EXEC audit.s_KVAdd @version, 'rows', @rows;
    EXEC audit.s_KVAdd @version, 'mach_nm', @mach_nm;
    EXEC audit.s_KVAdd @version, 'usr_nm', @usr_nm;
    EXEC audit.s_KVLog @version, 1;

GO
