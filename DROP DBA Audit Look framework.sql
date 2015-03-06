PRINT '--- deleting objects';
IF OBJECT_ID('Audit.s_RecreateTableTriggers','P') IS NOT NULL
    BEGIN
        PRINT 'drop Audit.s_RecreateTableTriggers procedure';
        DROP PROCEDURE Audit.s_RecreateTableTriggers;
    END
GO
IF OBJECT_ID('Audit.s_PopulateAuditConfig','P') IS NOT NULL
    BEGIN
        PRINT 'drop Audit.s_PopulateAuditConfig procedure';
        DROP PROCEDURE Audit.s_PopulateAuditConfig;
    END
GO
IF OBJECT_ID('dbo.s_LookUpsert','P') IS NOT NULL
    BEGIN
        PRINT 'drop dbo.s_LookUpsert procedure';
        DROP PROCEDURE dbo.s_LookUpsert;
    END
GO
IF OBJECT_ID('dbo.s_LookTypeUpsert','P') IS NOT NULL
    BEGIN
        PRINT 'drop dbo.s_LookTypeUpsert procedure';
        DROP PROCEDURE dbo.s_LookTypeUpsert
    END
GO
IF OBJECT_ID('DBA.s_DropObject','P') IS NOT NULL
    BEGIN
        PRINT 'drop DBA.s_DropObject procedure';
        DROP PROCEDURE DBA.s_DropObject;
    END
GO
IF OBJECT_ID('DBA.s_AddProcExecLog','P') IS NOT NULL
    BEGIN
        PRINT 'drop DBA.s_AddProcExecLog procedure';
        DROP PROCEDURE DBA.s_AddProcExecLog;
    END
GO
IF OBJECT_ID('DBA.s_AddSQLErrorLog','P') IS NOT NULL
    BEGIN
        PRINT 'drop DBA.s_AddSQLErrorLog procedure';
        DROP PROCEDURE DBA.s_AddSQLErrorLog;
    END
GO

IF OBJECT_ID('Audit.f_GetAuditSQL','FN') IS NOT NULL
    BEGIN
        PRINT 'drop Audit.f_GetAuditSQL function';
        DROP FUNCTION Audit.f_GetAuditSQL;
    END
GO

IF OBJECT_ID('dbo.f_LookIDByConstant','FN') IS NOT NULL
    BEGIN
        PRINT 'drop dbo.f_LookIDByConstant function';
        DROP FUNCTION dbo.f_LookIDByConstant;
    END
GO

IF OBJECT_ID('dbo.f_LookIDIsValid','FN') IS NOT NULL
    BEGIN
        PRINT 'drop dbo.f_LookIDIsValid function';
        DROP FUNCTION dbo.f_LookIDIsValid;
    END
GO

IF OBJECT_ID('Audit.v_Audit','V') IS NOT NULL
    BEGIN
        PRINT 'drop Audit.v_Audit view';
        DROP VIEW Audit.v_Audit;
    END
GO

IF OBJECT_ID('Audit.v_AuditKey','V') IS NOT NULL
    BEGIN
        PRINT 'drop Audit.v_AuditKey view';
        DROP VIEW Audit.v_AuditKey;
    END
GO

IF OBJECT_ID('dbo.v_Look','V') IS NOT NULL
    BEGIN
        PRINT 'drop dbo.v_Look view';
        DROP VIEW dbo.v_Look;
    END
GO

IF OBJECT_ID('Audit.Audit','U') IS NOT NULL
    BEGIN
        PRINT 'drop Audit.Audit table';
        DROP TABLE Audit.Audit;
    END
GO

IF OBJECT_ID('Audit.AuditConfig','U') IS NOT NULL
    BEGIN
        PRINT 'drop Audit.AuditConfig table';
        DROP TABLE Audit.AuditConfig;
    END
GO

IF OBJECT_ID('dbo.Look','U') IS NOT NULL
    BEGIN
        PRINT 'drop dbo.Look table';
        DROP TABLE dbo.Look;
    END
GO

IF OBJECT_ID('dbo.LookType','U') IS NOT NULL
    BEGIN
        PRINT 'drop dbo.LookType table';
        DROP TABLE dbo.LookType;
    END
GO

IF OBJECT_ID('DBA.LogProcExec','U') IS NOT NULL
    BEGIN
        PRINT 'drop DBA.LogProcExec table';
        DROP TABLE DBA.LogProcExec;
    END
GO

IF OBJECT_ID('DBA.LogSQLError','U') IS NOT NULL
    BEGIN
        PRINT 'drop DBA.LogSQLError table';
        DROP TABLE DBA.LogSQLError;
    END
GO

IF OBJECT_ID('DBA.TableLoadStatus','U') IS NOT NULL
    BEGIN
        PRINT 'drop DBA.TableLoadStatus table';
        DROP TABLE DBA.TableLoadStatus;
    END
GO

IF OBJECT_ID('dbo.f_QuoteString','FN') IS NOT NULL
    BEGIN
        PRINT 'drop dbo.f_QuoteString function';
        DROP FUNCTION dbo.f_QuoteString;
    END
GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE [schema_id] = SCHEMA_ID('Audit'))
    BEGIN
        PRINT '*** There are still objects referenced by Audit schema, so schema will not be dropped';
    END
ELSE
    BEGIN
        IF EXISTS (SELECT 0 FROM sys.schemas s WHERE s.name = 'Audit' AND schema_id NOT IN (SELECT schema_id FROM sys.objects WHERE name = 'Audit'))
            BEGIN
                PRINT 'dropping Audit schema';
                EXEC('DROP SCHEMA [Audit]');
            END
    END
GO 

IF EXISTS (SELECT 1 FROM sys.objects WHERE [schema_id] = SCHEMA_ID('DBA'))
    BEGIN
        PRINT '*** There are still objects referenced by DBA schema, so schema will not be dropped';
    END
ELSE
    BEGIN
        IF EXISTS (SELECT 0 FROM sys.schemas s WHERE s.name = 'DBA' AND schema_id NOT IN (SELECT schema_id FROM sys.objects WHERE name = 'DBA'))
            BEGIN
                PRINT 'dropping DBA schema';
                EXEC('DROP SCHEMA [DBA]');
            END
    END
GO 
