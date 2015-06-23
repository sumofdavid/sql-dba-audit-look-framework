SET NUMERIC_ROUNDABORT OFF;
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON;
SET XACT_ABORT ON;

DECLARE @new_version nvarchar(100) = N'01.00.03',
        @old_version nvarchar(100) = N'01.00.02',
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

	SET @xml = 
    (
    SELECT
        'proc exec' AS evt_type,
        'info' AS evt_status,
        COALESCE(@app_nm,'') AS app_nm,
        COALESCE(@@SERVERNAME,'') AS srv_nm,
        'deprecated: Procedure should not be used, use KV framework.' AS feature_info, 
        COALESCE(DB_NAME(@db_id),'') AS db_nm,
        COALESCE(OBJECT_SCHEMA_NAME(@object_id, @db_id),'') AS sch_nm,
		@start AS bgn_dt,
		@end AS end_dt,
		COALESCE(@db_id,0) AS [db_id],
		COALESCE(@version,NEWID()) AS [uid],
		COALESCE(@object_id,0) AS obj_id,
		COALESCE(OBJECT_NAME(@object_id, @db_id),COALESCE(@object_nm,'unknown')) AS obj_nm,
		COALESCE(@section,'') AS sec_nm,
		COALESCE(@event_info,'') AS evt_txt,
		COALESCE(@extra_info,'') AS evt_info,
		COALESCE(@rows,'') AS [rows],
        COALESCE(HOST_NAME(),'') AS mach_nm,
        COALESCE(ORIGINAL_LOGIN(),'') AS usr_nm
        FOR XML RAW ('event'), ELEMENTS
    );

    -- Log it
    INSERT INTO audit.EventSink (EventMessage) VALUES (@xml)

GO
