CREATE SCHEMA [qte]
AUTHORIZATION [dbo]
GO
/****** Object:  StoredProcedure [dbo].[uspLogError]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--============================================================================
-- System Name: AMFI
--  
-- Process/Module: Stored Procedure
--  
-- Object Name: dbo.uspLogError.sql  
--  
-- Creation Date: 7/20/2011
--  
-- Author: Bill Boppel
--  
-- Description: 
--
-- Inspired by: http://sqlfool.com/2008/12/error-handling-in-t-sql/
--  
------------------------------------------------------------------------------  
--	Parameters   
--	Name				DataType/Size	I/O  
------------------------------------------------------------------------------  
--	Tables accessed:  
------------------------------------------------------------------------------  
--	Returned columns  
--	
------------------------------------------------------------------------------  
--	History   
--	Ticket Nbr  Author		Date Changed	Description
--  
------------------------------------------------------------------------------
--============================================================================
/***************************************************************
	Name:       dba_logError_sp
 
	Author:     Michelle F. Ufford, http://sqlfool.com
 
	Purpose:    Retrieves error information and logs in the 
						dba_errorLog table.
 
		@errorType = options are "app" or "sys"; "app" are custom 
				application errors, i.e. business logic errors;
				"sys" are system errors, i.e. PK errors
 
		@app_errorProcedure = stored procedure name, 
				needed for app errors
 
		@app_errorMessage = custom app error message
 
		@procParameters = optional; log the parameters that were passed
				to the proc that resulted in an error
 
		@userFriendly = displays a generic error message if = 1
 
		@forceExit = forces the proc to rollback and exit; 
				mostly useful for application errors.
 
		@returnError = returns the error to the calling app if = 1
 
	Called by:	Another stored procedure
 
	Date        Initials    Description
	----------------------------------------------------------------------------
	2008-12-16  MFU         Initial Release
****************************************************************
	Exec dbo.dba_logError_sp
		@errorType          = 'app'
	  , @app_errorProcedure = 'someTableInsertProcName'
	  , @app_errorMessage   = 'Some app-specific error message'
	  , @userFriendly       = 1
	  , @forceExit          = 1
	  , @returnError        = 1;
****************************************************************/
Create Procedure [dbo].[uspLogError]
(
    /* Declare Parameters */
      @errorType            char(3)         = 'sys'
    , @app_errorProcedure   varchar(50)     = ''
    , @app_errorMessage     nvarchar(4000)  = ''
    , @procParameters       nvarchar(4000)  = ''
    , @userFriendly         bit             = 0
    , @forceExit            bit             = 1
    , @returnError          bit             = 1
)
As
 
Set NoCount On;
Set XACT_Abort On;
 
Begin
 
    /* Declare Variables */
    Declare	@errorNumber            int
            , @errorProcedure       varchar(50)
            , @dbName               sysname
            , @errorLine            int
            , @errorMessage         nvarchar(4000)
            , @errorSeverity        int
            , @errorState           int
            , @errorReturnMessage   nvarchar(4000)
            , @errorReturnSeverity  int
            , @currentDateTime      smalldatetime;
 
    Declare @errorReturnID Table (errorID varchar(10));
 
    /* Initialize Variables */
    Select @currentDateTime = GetDate();
 
    /* Capture our error details */
    If @errorType = 'sys' 
    Begin
 
        /* Get our system error details and hold it */
        Select 
              @errorNumber      = Error_Number()
            , @errorProcedure   = Error_Procedure()
            , @dbName           = DB_Name()
            , @errorLine        = Error_Line()
            , @errorMessage     = Error_Message()
            , @errorSeverity    = Error_Severity()
            , @errorState       = Error_State() ;
 
    End
    Else
    Begin
 
    	/* Get our custom app error details and hold it */
        Select 
              @errorNumber      = 0
            , @errorProcedure   = @app_errorProcedure
            , @dbName           = DB_Name()
            , @errorLine        = 0
            , @errorMessage     = @app_errorMessage
            , @errorSeverity    = 0
            , @errorState       = 0 ;
 
    End;
 
    /* And keep a copy for our logs */
    Insert Into dbo.dba_errorLog
    (
          errorType
        , errorDate
        , errorLine
        , errorMessage
        , errorNumber
        , errorProcedure
        , procParameters
        , errorSeverity
        , errorState
        , databaseName
        , systemUser 
	)
    OutPut Inserted.errorLog_id Into @errorReturnID
    Values
    (
          @errorType
        , @currentDateTime
        , @errorLine
        , @errorMessage
        , @errorNumber
        , @errorProcedure
        , @procParameters
        , @errorSeverity
        , @errorState
        , @dbName
        , SYSTEM_USER
    );
 
    /* Should we display a user friendly message to the application? */
    If @userFriendly = 1
        Select @errorReturnMessage = 'An error has occurred in the database (' + errorID + ')'
        From @errorReturnID;
    Else 
        Select @errorReturnMessage = @errorMessage;
 
    /* Do we want to force the application to exit? */
    If @forceExit = 1
        Select @errorReturnSeverity = 15
    Else
        Select @errorReturnSeverity = @errorSeverity;
 
    /* Should we return an error message to the calling proc? */
    If @returnError = 1
        Raiserror 
        (
              @errorReturnMessage
            , @errorReturnSeverity
            , 1
        ) With NoWait;
 
    Set NoCount Off;
    Return 0;
 
End

GO
/****** Object:  StoredProcedure [qte].[uspCreateSettlementProposal]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--DECLARE @MY_ReturnValue AS INT
--DECLARE @MY_IRR AS FLOAT 
--EXEC @MY_ReturnValue = qte.uspCreateSettlementProposal @QuoteID=1, @IRR=@MY_IRR OUTPUT
--SELECT @MY_IRR AS IRR, @MY_ReturnValue AS ReturnCode
--============================================================================
CREATE PROCEDURE [qte].[uspCreateSettlementProposal]
    (
      @QuoteID AS INT ,
      @IRR FLOAT OUTPUT
    )
AS
    BEGIN

        SET NOCOUNT ON;

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT; 
		
		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;

        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'QuoteID = ' + CAST(@QuoteID AS VARCHAR(20));

        DECLARE @QuoteTotal AS DECIMAL(18, 2);
		
        DECLARE @Factor AS FLOAT;
        DECLARE @SumFx2 AS FLOAT;
        DECLARE @SumFx3 AS FLOAT;
        DECLARE @x AS FLOAT;

        DECLARE @IRR_Floor AS DECIMAL(19, 17);
        DECLARE @IRR_Ceiling AS DECIMAL(19, 17);
		DECLARE @IRR_Current FLOAT 
        DECLARE @Incr AS DECIMAL(19, 17);
        DECLARE @i INT;
		DECLARE @Iterations AS INT;
        DECLARE @GoalSeekLoop AS INT;
        DECLARE @GoalSeekLoopMax AS INT;




        SET @x = 1.;
        SET @SumFx2 = 0.0;
		
        DECLARE @GoalSeekTries AS INT;
        SET @GoalSeekTries = 0;

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

                    SELECT  @QuoteTotal = SUM(PremiumAmt)
                    FROM    qte.BenefitQuote
                    WHERE   QuoteID = @QuoteID;

                    UPDATE  ps
                    SET     BenefitAmt = bq.BenefitAmt
                    FROM    qte.PaymentStream ps
                            INNER JOIN qte.BenefitQuote bq ON bq.BenefitQuoteID = ps.BenefitQuoteID
                    WHERE   bq.QuoteID = @QuoteID;

                    DECLARE @SettlementHdr TABLE
                        (
                          AnnuityAccumMonth INT ,
                          ExpectedTTotal FLOAT ,
                          Fx1 FLOAT ,
                          Fx2 FLOAT ,
                          Fx3 FLOAT
                        );

                    DECLARE @SettlementDtl TABLE
                        (
                          BenefitQuoteID INT ,
                          AnnuityAccumMonth INT ,
                          ExpectedT FLOAT
                        );


--                    SET @SumFx2 = @QuoteTotal + 1; -- force the first loop
        
                    --WHILE @GoalSeekTries < 1
                    --    AND ABS(@QuoteTotal - @SumFx2) > 0.01
                    --    BEGIN
	--=======================================================
	-- Interations
	--=======================================================
    SET @IRR_Floor  = 0.01;
    SET @IRR_Ceiling = 0.09;
    SET @Incr = 0.01;

    SET @Iterations = 1;
    SET @IRR_Current = @IRR_Floor


--=============================================
                    WHILE @Iterations < 4
                        BEGIN

                            SET @GoalSeekLoop = 0;
                            SET @GoalSeekLoopMax = 100;
							SET @IRR_Current = @IRR_Floor

                            WHILE @GoalSeekLoop < @GoalSeekLoopMax
                                BEGIN

							DELETE @SettlementDtl
							DELETE @SettlementHdr

							--SET @Factor = 1 / @x;
							SET @Factor = POWER(@IRR_Current + 1, 1. / 12.);


					;
                            WITH    cte ( BenefitQuoteID, AnnuityAccumMonth, ExpectedT )
                                      AS ( SELECT   ps.BenefitQuoteID ,
                                                    ps.AnnuityAccumMonth ,
--                                SUM(CertainAmt) * ps.BenefitAmt AS TotalGuaranteed ,
                                                    SUM(ExpectedT) * ps.BenefitAmt AS TotalExpectedT 
--                                SUM(ExpectedN) * ps.BenefitAmt AS TotalExpectedN
                                           FROM     qte.Quote q
                                                    INNER JOIN qte.BenefitQuote bq ON bq.QuoteID = q.QuoteID
                                                    INNER JOIN qte.PaymentStream ps ON ps.BenefitQuoteID = bq.BenefitQuoteID
                                           WHERE    q.QuoteID = @QuoteID
                                           GROUP BY ps.BenefitQuoteID ,
                                                    ps.AnnuityAccumMonth ,
                                                    ps.BenefitAmt
                                         )
                                INSERT  INTO @SettlementDtl
                                        ( BenefitQuoteID ,
                                          AnnuityAccumMonth ,
                                          ExpectedT
					                    )
                                        SELECT  BenefitQuoteID ,
                                                AnnuityAccumMonth ,
                                                ExpectedT
                                        FROM    cte; 


                            INSERT  INTO @SettlementHdr
                                    ( AnnuityAccumMonth ,
                                      ExpectedTTotal
					                )
                                    SELECT  AnnuityAccumMonth ,
                                            SUM(ExpectedT)
                                    FROM    @SettlementDtl
                                    GROUP BY AnnuityAccumMonth;

                            UPDATE  @SettlementHdr
                            SET     Fx1 = 1 ,
                                    Fx2 = ExpectedTTotal
                            WHERE   AnnuityAccumMonth = 0;


					;
                            WITH    cte
                                      AS ( SELECT   AnnuityAccumMonth ,
                                                    Fx1
                                           FROM     @SettlementHdr
                                         ),
                                    rcte
                                      AS ( SELECT   AnnuityAccumMonth ,
                                                    Fx1
                                           FROM     cte
                                           WHERE    cte.AnnuityAccumMonth = 0
                                           UNION ALL
                                           SELECT   c.AnnuityAccumMonth ,
--                                                    Fx1 = r.Fx1 / @x
                                                    Fx1 = r.Fx1 / @Factor
                                           FROM     cte c
                                                    INNER JOIN rcte r ON c.AnnuityAccumMonth = r.AnnuityAccumMonth + 1
                                         )
                                UPDATE  s
                                SET     Fx1 = r.Fx1
                                FROM    @SettlementHdr s
                                        INNER JOIN rcte r ON s.AnnuityAccumMonth = r.AnnuityAccumMonth
                                OPTION  ( MAXRECURSION 1441 );

                            UPDATE  s
                            SET     Fx2 = Fx1 * ExpectedTTotal 
							--,
       --                             Fx3 = ExpectedTTotal * AnnuityAccumMonth * POWER(@x, AnnuityAccumMonth - 1)
                            FROM    @SettlementHdr s;


                            SELECT  @SumFx2 = SUM(Fx2) 
							--,
       --                             @SumFx3 = SUM(Fx3)
                            FROM    @SettlementHdr;

							--SET @x = @x - ((@SumFx2 - @QuoteTotal) / @SumFx3)

--SELECT @SumFx2 AS SumFx2, @SumFx3 AS SumFx3, @x AS xPlusOne, @Factor AS Factor
--SELECT @SumFx2 AS SumFx2
--SELECT * FROM @SettlementHdr

--SELECT 'Before Comparison'
--, @SumFx2 AS SumFx2
--, @QuoteTotal AS QuoteTotal
--, @IRR_Current AS IRR_Current
--, @IRR_Floor AS IRR_Floor
--, @IRR_Ceiling AS IRR_Ceiling
--, @GoalSeekLoop AS GoalSeekLoop
--, @Incr AS Incr
--, @Iterations AS Iterations


                                    --SET @GoalSeekLoop = @GoalSeekLoop + 1;

                                    IF @SumFx2 < @QuoteTotal 
                                        BEGIN
											--SET @IRR_Current = ROUND(@IRR_Current, @Iterations);
											
											
											SET @IRR_Floor = @IRR_Current - @Incr;
											
											SET @IRR_Ceiling = @IRR_Current;
                                            
											SET @GoalSeekLoop = @GoalSeekLoopMax;


--SELECT 'Less than'
--, @SumFx2 AS SumFx2
--, @QuoteTotal AS QuoteTotal
--, @IRR_Current AS IRR_Current
--, @IRR_Floor AS IRR_Floor
--, @IRR_Ceiling AS IRR_Ceiling
--, @GoalSeekLoop AS GoalSeekLoop
--, @Incr AS Incr
--, @Iterations AS Iterations


                                        END;
                                    ELSE
                                        BEGIN
--											SET @IRR_Current = ROUND(@IRR_Current, @Iterations);



											SET @IRR_Current = @IRR_Current + @Incr;
                                            SET @GoalSeekLoop = @GoalSeekLoop + 1;
--SELECT 'Greater than or equal'
--, @SumFx2 AS SumFx2
--, @QuoteTotal AS QuoteTotal
--, @IRR_Current AS IRR_Current
--, @IRR_Floor AS IRR_Floor
--, @IRR_Ceiling AS IRR_Ceiling
--, @GoalSeekLoop AS GoalSeekLoop
--, @Incr AS Incr
--, @Iterations AS Iterations
                                        END;
                                END;

                            SET @Incr = CAST(@Incr / 10. AS DECIMAL(19, 17));

                            SET @Iterations = @Iterations + 1;

                        END;
--=====================================================







							
--							SET @GoalSeekTries = @GoalSeekTries + 1

--							DELETE @SettlementDtl
--							DELETE @SettlementHdr

--							SET @Factor = 1 / @x;

--					;
--                            WITH    cte ( BenefitQuoteID, AnnuityAccumMonth, ExpectedT )
--                                      AS ( SELECT   ps.BenefitQuoteID ,
--                                                    ps.AnnuityAccumMonth ,
----                                SUM(CertainAmt) * ps.BenefitAmt AS TotalGuaranteed ,
--                                                    SUM(ExpectedT) * ps.BenefitAmt AS TotalExpectedT 
----                                SUM(ExpectedN) * ps.BenefitAmt AS TotalExpectedN
--                                           FROM     qte.Quote q
--                                                    INNER JOIN qte.BenefitQuote bq ON bq.QuoteID = q.QuoteID
--                                                    INNER JOIN qte.PaymentStream ps ON ps.BenefitQuoteID = bq.BenefitQuoteID
--                                           WHERE    q.QuoteID = @QuoteID
--                                           GROUP BY ps.BenefitQuoteID ,
--                                                    ps.AnnuityAccumMonth ,
--                                                    ps.BenefitAmt
--                                         )
--                                INSERT  INTO @SettlementDtl
--                                        ( BenefitQuoteID ,
--                                          AnnuityAccumMonth ,
--                                          ExpectedT
--					                    )
--                                        SELECT  BenefitQuoteID ,
--                                                AnnuityAccumMonth ,
--                                                ExpectedT
--                                        FROM    cte; 


--                            INSERT  INTO @SettlementHdr
--                                    ( AnnuityAccumMonth ,
--                                      ExpectedTTotal
--					                )
--                                    SELECT  AnnuityAccumMonth ,
--                                            SUM(ExpectedT)
--                                    FROM    @SettlementDtl
--                                    GROUP BY AnnuityAccumMonth;

--                            UPDATE  @SettlementHdr
--                            SET     Fx1 = 1 ,
--                                    Fx2 = ExpectedTTotal
--                            WHERE   AnnuityAccumMonth = 0;


--					;
--                            WITH    cte
--                                      AS ( SELECT   AnnuityAccumMonth ,
--                                                    Fx1
--                                           FROM     @SettlementHdr
--                                         ),
--                                    rcte
--                                      AS ( SELECT   AnnuityAccumMonth ,
--                                                    Fx1
--                                           FROM     cte
--                                           WHERE    cte.AnnuityAccumMonth = 0
--                                           UNION ALL
--                                           SELECT   c.AnnuityAccumMonth ,
--                                                    Fx1 = r.Fx1 / @x
--                                           FROM     cte c
--                                                    INNER JOIN rcte r ON c.AnnuityAccumMonth = r.AnnuityAccumMonth + 1
--                                         )
--                                UPDATE  s
--                                SET     Fx1 = r.Fx1
--                                FROM    @SettlementHdr s
--                                        INNER JOIN rcte r ON s.AnnuityAccumMonth = r.AnnuityAccumMonth
--                                OPTION  ( MAXRECURSION 1441 );

--                            UPDATE  s
--                            SET     Fx2 = Fx1 * ExpectedTTotal ,
--                                    Fx3 = ExpectedTTotal * AnnuityAccumMonth * POWER(@x, AnnuityAccumMonth - 1)
--                            FROM    @SettlementHdr s;


--                            SELECT  @SumFx2 = SUM(Fx2) ,
--                                    @SumFx3 = SUM(Fx3)
--                            FROM    @SettlementHdr;

--							SET @x = @x - ((@SumFx2 - @QuoteTotal) / @SumFx3)

--SELECT @SumFx2 AS SumFx2, @SumFx3 AS SumFx3, @x AS xPlusOne, @Factor AS Factor
--SELECT * FROM @SettlementHdr

--                        END;	-- WHILE @GoalSeekTries < 4
                    

--SELECT @QuoteTotal
                    --SELECT  *
                    --FROM    @SettlementHdr;



                    SET @IRR = POWER(@Factor, 12) - 1;
                    SET @IRR = @IRR_Current

                    COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;

    END;






GO
/****** Object:  StoredProcedure [qte].[uspCreateSettlementProposal_Seq]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


--DECLARE @MY_ReturnValue AS INT
--DECLARE @MY_IRR AS FLOAT 
--EXEC @MY_ReturnValue = qte.uspCreateSettlementProposal @QuoteID=1, @IRR=@MY_IRR OUTPUT
--SELECT @MY_IRR AS IRR, @MY_ReturnValue AS ReturnCode
--============================================================================
CREATE PROCEDURE [qte].[uspCreateSettlementProposal_Seq]
    (
      @QuoteID AS INT ,
      @IRR DECIMAL(19,4) OUTPUT ,
      @EquivalentCash DECIMAL(19,2) OUTPUT
    )
AS
    BEGIN

        SET NOCOUNT ON;

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT; 
		
		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;

        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'QuoteID = ' + CAST(@QuoteID AS VARCHAR(20));

        DECLARE @QuoteTotal AS DECIMAL(18, 2);
		
        DECLARE @Factor AS FLOAT;
        DECLARE @SumFx2 AS FLOAT;
        DECLARE @SumFx3 AS FLOAT;
        DECLARE @x AS FLOAT;

        DECLARE @IRR_Floor AS DECIMAL(19, 17);
        DECLARE @IRR_Ceiling AS DECIMAL(19, 17);
		DECLARE @IRR_Current FLOAT 
        DECLARE @Incr AS DECIMAL(19, 17);
        DECLARE @i INT;
        DECLARE @GoalSeekLoop AS INT;
        DECLARE @GoalSeekLoopMax AS INT;


        SET @x = 1.;
        SET @SumFx2 = 0.0;
		
        DECLARE @GoalSeekTries AS INT;
        SET @GoalSeekTries = 0;

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

                    SELECT  @QuoteTotal = SUM(PremiumAmt) + 750.0
                    FROM    qte.BenefitQuote
                    WHERE   QuoteID = @QuoteID;

                    UPDATE  ps
                    SET     BenefitAmt = bq.BenefitAmt
                    FROM    qte.PaymentStream ps
                            INNER JOIN qte.BenefitQuote bq ON bq.BenefitQuoteID = ps.BenefitQuoteID
                    WHERE   bq.QuoteID = @QuoteID;

                    DECLARE @SettlementHdr TABLE
                        (
                          AnnuityAccumMonth INT ,
                          ExpectedTTotal FLOAT ,
                          Fx1 FLOAT ,
                          Fx2 FLOAT ,
                          Fx3 FLOAT
                        );

                    DECLARE @SettlementDtl TABLE
                        (
                          BenefitQuoteID INT ,
                          AnnuityAccumMonth INT ,
                          ExpectedT FLOAT
                        );


	--=======================================================
	-- Interations
	--=======================================================
    SET @IRR_Floor  = 0.0243;
    SET @IRR_Ceiling = 0.0500;
    SET @Incr = 0.0001;

    SET @IRR_Current = @IRR_Floor


                            SET @GoalSeekLoop = 0;
                            SET @GoalSeekLoopMax = 300;
--							SET @IRR_Current = @IRR_Floor

                            WHILE @GoalSeekLoop < @GoalSeekLoopMax
                                BEGIN

							DELETE @SettlementDtl
							DELETE @SettlementHdr

							SET @Factor = POWER(@IRR_Current + 1, 1. / 12.);


					;
                            WITH    cte ( BenefitQuoteID, AnnuityAccumMonth, ExpectedT )
                                      AS ( SELECT   ps.BenefitQuoteID ,
                                                    ps.AnnuityAccumMonth ,
                                                    SUM(ExpectedT) * ps.BenefitAmt AS TotalExpectedT 
                                           FROM     qte.Quote q
                                                    INNER JOIN qte.BenefitQuote bq ON bq.QuoteID = q.QuoteID
                                                    INNER JOIN qte.PaymentStream ps ON ps.BenefitQuoteID = bq.BenefitQuoteID
                                           WHERE    q.QuoteID = @QuoteID
                                           GROUP BY ps.BenefitQuoteID ,
                                                    ps.AnnuityAccumMonth ,
                                                    ps.BenefitAmt
                                         )
                                INSERT  INTO @SettlementDtl
                                        ( BenefitQuoteID ,
                                          AnnuityAccumMonth ,
                                          ExpectedT
					                    )
                                        SELECT  BenefitQuoteID ,
                                                AnnuityAccumMonth ,
                                                ExpectedT
                                        FROM    cte; 


                            INSERT  INTO @SettlementHdr
                                    ( AnnuityAccumMonth ,
                                      ExpectedTTotal
					                )
                                    SELECT  AnnuityAccumMonth ,
                                            SUM(ExpectedT)
                                    FROM    @SettlementDtl
                                    GROUP BY AnnuityAccumMonth;

                            UPDATE  @SettlementHdr
                            SET     Fx1 = 1 ,
                                    Fx2 = ExpectedTTotal
                            WHERE   AnnuityAccumMonth = 0;


					;
                            WITH    cte
                                      AS ( SELECT   AnnuityAccumMonth ,
                                                    Fx1
                                           FROM     @SettlementHdr
                                         ),
                                    rcte
                                      AS ( SELECT   AnnuityAccumMonth ,
                                                    Fx1
                                           FROM     cte
                                           WHERE    cte.AnnuityAccumMonth = 0
                                           UNION ALL
                                           SELECT   c.AnnuityAccumMonth ,
--                                                    Fx1 = r.Fx1 / @x
                                                    Fx1 = r.Fx1 / @Factor
                                           FROM     cte c
                                                    INNER JOIN rcte r ON c.AnnuityAccumMonth = r.AnnuityAccumMonth + 1
                                         )
                                UPDATE  s
                                SET     Fx1 = r.Fx1
                                FROM    @SettlementHdr s
                                        INNER JOIN rcte r ON s.AnnuityAccumMonth = r.AnnuityAccumMonth
                                OPTION  ( MAXRECURSION 1441 );

                            UPDATE  s
                            SET     Fx2 = Fx1 * ExpectedTTotal 
                            FROM    @SettlementHdr s;


                            SELECT  @SumFx2 = SUM(Fx2) 
                            FROM    @SettlementHdr;

							--SET @x = @x - ((@SumFx2 - @QuoteTotal) / @SumFx3)

--SELECT @SumFx2 AS SumFx2, @SumFx3 AS SumFx3, @x AS xPlusOne, @Factor AS Factor
--SELECT @SumFx2 AS SumFx2
--SELECT * FROM @SettlementHdr

--SELECT 'Before Comparison'
--, @SumFx2 AS SumFx2
--, @QuoteTotal AS QuoteTotal
--, @IRR_Current AS IRR_Current
--, @IRR_Floor AS IRR_Floor
--, @IRR_Ceiling AS IRR_Ceiling
--, @GoalSeekLoop AS GoalSeekLoop
--, @Incr AS Incr


                                    --SET @GoalSeekLoop = @GoalSeekLoop + 1;

                                    IF @SumFx2 < @QuoteTotal 
                                        BEGIN
											
											--SET @IRR_Floor = @IRR_Current - @Incr;
											--SET @IRR_Ceiling = @IRR_Current;
											SET @GoalSeekLoop = @GoalSeekLoopMax;

											SET @IRR_Current = @IRR_Current - @Incr;
--SELECT 'Less than'
--, @SumFx2 AS SumFx2
--, @QuoteTotal AS QuoteTotal
--, @IRR_Current AS IRR_Current
--, @IRR_Floor AS IRR_Floor
--, @IRR_Ceiling AS IRR_Ceiling
--, @GoalSeekLoop AS GoalSeekLoop
--, @Incr AS Incr


                                        END;
                                    ELSE
                                        BEGIN

											SET @IRR_Current = @IRR_Current + @Incr;
                                            SET @GoalSeekLoop = @GoalSeekLoop + 1;
--SELECT 'Greater than or equal'
--, @SumFx2 AS SumFx2
--, @QuoteTotal AS QuoteTotal
--, @IRR_Current AS IRR_Current
--, @IRR_Floor AS IRR_Floor
--, @IRR_Ceiling AS IRR_Ceiling
--, @GoalSeekLoop AS GoalSeekLoop
--, @Incr AS Incr
                                        END;
                                END;

--                            SET @Incr = CAST(@Incr / 10. AS DECIMAL(19, 17));


--=====================================================

--SELECT @SumFx2 AS SumFx2, @SumFx3 AS SumFx3, @x AS xPlusOne, @Factor AS Factor
--SELECT * FROM @SettlementHdr



--=========================================================
-- Equivalent Cash
--=========================================================
	DECLARE @IRR_EquivalentCash FLOAT 
    SET @IRR_EquivalentCash = 0.04;

	DELETE @SettlementDtl
	DELETE @SettlementHdr

	SET @Factor = POWER(@IRR_EquivalentCash + 1, 1. / 12.);

	;
            WITH    cte ( BenefitQuoteID, AnnuityAccumMonth, ExpectedT )
                        AS ( SELECT   ps.BenefitQuoteID ,
                                    ps.AnnuityAccumMonth ,
                                    SUM(ExpectedT) * ps.BenefitAmt AS TotalExpectedT 
                            FROM     qte.Quote q
                                    INNER JOIN qte.BenefitQuote bq ON bq.QuoteID = q.QuoteID
                                    INNER JOIN qte.PaymentStream ps ON ps.BenefitQuoteID = bq.BenefitQuoteID
                            WHERE    q.QuoteID = @QuoteID
                            GROUP BY ps.BenefitQuoteID ,
                                    ps.AnnuityAccumMonth ,
                                    ps.BenefitAmt
                            )
                INSERT  INTO @SettlementDtl
                        ( BenefitQuoteID ,
                            AnnuityAccumMonth ,
                            ExpectedT
					    )
                        SELECT  BenefitQuoteID ,
                                AnnuityAccumMonth ,
                                ExpectedT
                        FROM    cte; 


                INSERT  INTO @SettlementHdr
                        ( AnnuityAccumMonth ,
                            ExpectedTTotal
					    )
                        SELECT  AnnuityAccumMonth ,
                                SUM(ExpectedT)
                        FROM    @SettlementDtl
                        GROUP BY AnnuityAccumMonth;

                UPDATE  @SettlementHdr
                SET     Fx1 = 1 ,
                        Fx2 = ExpectedTTotal
                WHERE   AnnuityAccumMonth = 0;

		;
                WITH    cte
                            AS ( SELECT   AnnuityAccumMonth ,
                                        Fx1
                                FROM     @SettlementHdr
                                ),
                        rcte
                            AS ( SELECT   AnnuityAccumMonth ,
                                        Fx1
                                FROM     cte
                                WHERE    cte.AnnuityAccumMonth = 0
                                UNION ALL
                                SELECT   c.AnnuityAccumMonth ,
--                                                    Fx1 = r.Fx1 / @x
                                        Fx1 = r.Fx1 / @Factor
                                FROM     cte c
                                        INNER JOIN rcte r ON c.AnnuityAccumMonth = r.AnnuityAccumMonth + 1
                                )
                    UPDATE  s
                    SET     Fx1 = r.Fx1
                    FROM    @SettlementHdr s
                            INNER JOIN rcte r ON s.AnnuityAccumMonth = r.AnnuityAccumMonth
                    OPTION  ( MAXRECURSION 1441 );

                UPDATE  s
                SET     Fx2 = Fx1 * ExpectedTTotal 
                FROM    @SettlementHdr s;

                SELECT  @EquivalentCash = CAST(SUM(Fx2) AS DECIMAL(19,2))
                FROM    @SettlementHdr;


                --SET @IRR = CAST(POWER(@Factor, 12) - 1 AS DECIMAL(19,4));
                SET @IRR = CAST(@IRR_Current AS DECIMAL(19,4));

                    COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;

    END;







GO
/****** Object:  StoredProcedure [qte].[uspCreateSpotInterest]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


--DECLARE @MY_ReturnValue AS INT
--EXEC @MY_ReturnValue = qte.uspCreateSpotInterest @RateVersionID=1
--SELECT @MY_ReturnValue as ReturnCode
--============================================================================
CREATE PROCEDURE [qte].[uspCreateSpotInterest] ( @RateVersionID INT )
AS
    BEGIN

        SET NOCOUNT ON;

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT; 
		
        DECLARE @ImprovementPct AS FLOAT;
        DECLARE @AnnuityYear AS TINYINT;

		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;

        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'RateVersionID = ' + CAST(@RateVersionID AS VARCHAR);

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

                    DECLARE @SpotRateHdrID AS INT;
                    SELECT  @SpotRateHdrID = SpotRateHdrID
                    FROM    qte.RateVersion rv
                    WHERE   rv.RateVersionID = @RateVersionID;

                    DECLARE @SpotWeightHdrID AS INT;
                    SELECT  @SpotWeightHdrID = SpotWeightHdrID
                    FROM    qte.RateVersion rv
                    WHERE   rv.RateVersionID = @RateVersionID;

                    WITH    si ( Number )
                              AS ( SELECT   0 AS Number
                                   UNION ALL
                                   SELECT   Number + 1
                                   FROM     si
                                   WHERE    Number < 1440
                                 )
                        INSERT  INTO qte.SpotInterest
                                ( RateVersionID ,
                                  AnnuityYear ,
                                  AnnuityMonth ,
                                  AnnuityAccumMonth 
                                )
                                SELECT  @RateVersionID ,
                                        ( ( Number - 1 ) / 12 ) + 1 AS AnnuityYear ,
                                        CASE WHEN Number = 0 THEN 0
                                             ELSE CASE WHEN ( Number % 12 ) = 0 THEN 12
                                                       ELSE ( Number % 12 )
                                                  END
                                        END AS AnnuityMonth ,
                                        Number AS AnnuityAccumMonth
                                FROM    si
                                        LEFT JOIN qte.SpotRate sr ON CASE WHEN ( ( ( ( Number - 1 ) / 12 ) + 1 ) % 30 ) = 0 THEN 30
                                                                          ELSE ( ( ( ( Number - 1 ) / 12 ) + 1 ) % 30 )
                                                                     END = sr.AnnuityYear
                                WHERE   sr.SpotRateHdrID = @SpotRateHdrID
                        OPTION  ( MAXRECURSION 1440 );

                    UPDATE  si
                    SET     DiscountRate = CASE WHEN si.AnnuityAccumMonth = 0 THEN 0
                                                WHEN si.AnnuityAccumMonth >= 1
                                                     AND si.AnnuityAccumMonth <= 12
                                                THEN ( src.SpotRate * sw.Weight1 ) + ( ISNULL(srp.SpotRate, 0) * sw.Weight2 )
                                                ELSE (( src.SpotRate * sw.Weight1 ) + ( ISNULL(srp.SpotRate, 0) * sw.Weight2 )) / 12
                                           END
                    FROM    qte.SpotInterest si
                            INNER JOIN qte.SpotRate src ON si.AnnuityYear = src.AnnuityYear
                            LEFT JOIN qte.SpotRate srp ON src.AnnuityYear = srp.AnnuityYear + 1
                            INNER JOIN qte.SpotWeight sw ON sw.AnnuityAccumMonth = si.AnnuityAccumMonth
                    WHERE   si.AnnuityYear < 31
                            AND si.RateVersionID = @RateVersionID
                            AND src.SpotRateHdrID = @SpotRateHdrID
                            AND ISNULL(srp.SpotRateHdrID, @SpotRateHdrID) = @SpotRateHdrID
                            AND sw.SpotWeightHdrID = @SpotWeightHdrID;

                    DECLARE @TmpDiscountRate AS FLOAT;
                    SELECT  @TmpDiscountRate = DiscountRate
                    FROM    qte.SpotInterest
                    WHERE   AnnuityAccumMonth = 360
                            AND RateVersionID = @RateVersionID;

                    UPDATE  qte.SpotInterest
                    SET     DiscountRate = @TmpDiscountRate
                    WHERE   AnnuityAccumMonth > 360
                            AND RateVersionID = @RateVersionID;

                    UPDATE  qte.SpotInterest
                    SET     SpotInterestVx = POWER(( 1 + DiscountRate ), ( -AnnuityAccumMonth / 12. ))
                    WHERE   RateVersionID = @RateVersionID;

                    COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;

    END;


GO
/****** Object:  StoredProcedure [qte].[uspDeleteBenefitQuote]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--EXEC qte.uspDeleteBenefitQuote @BenefitQuoteID=1
--============================================================================
CREATE PROCEDURE [qte].[uspDeleteBenefitQuote]
    (
      @BenefitQuoteID INT
    )
AS
    BEGIN

        SET NOCOUNT ON;

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT ,
            @TransactionDate AS DATETIME;

		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;
        SET @TransactionDate = GETDATE();
					
        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'BenefitQuoteID = ' + CAST(@BenefitQuoteID AS VARCHAR(10));

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

						DELETE qte.PaymentStream
						WHERE BenefitQuoteID = @BenefitQuoteID

						DELETE qte.BenefitQuote
						WHERE BenefitQuoteID = @BenefitQuoteID

						SET @SqlReturnSts = 0;

                    IF @@TRANCOUNT > 0
                        COMMIT TRANSACTION;

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;
    END;
GO
/****** Object:  StoredProcedure [qte].[uspDeleteBroker]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--EXEC qte.uspDeleteBroker @StlmtBrokerID=1
--============================================================================
CREATE PROCEDURE [qte].[uspDeleteBroker]
    (
      @StlmtBrokerID INT
    )
AS
    BEGIN

        SET NOCOUNT ON;

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT ,
            @TransactionDate AS DATETIME;

		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;
        SET @TransactionDate = GETDATE();
					
        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'StlmtBrokerID = ' + CAST(@StlmtBrokerID AS VARCHAR(10));

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

                    IF EXISTS ( SELECT TOP 1
                                        *
                                FROM    qte.Quote
                                WHERE   StlmtBrokerID = @StlmtBrokerID )
                        BEGIN
							SET @SqlReturnSts = 1;
						END
                    ELSE
                        BEGIN

							DELETE qte.StlmtBroker
							WHERE StlmtBrokerID = @StlmtBrokerID

							SET @SqlReturnSts = 0;
						END

                    IF @@TRANCOUNT > 0
                        COMMIT TRANSACTION;

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;
    END;
GO
/****** Object:  StoredProcedure [qte].[uspGetAnnuitants]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- EXEC qte.uspGetAnnuitants @QuoteID=1
--============================================================================
CREATE PROCEDURE [qte].[uspGetAnnuitants] ( @QuoteID INT )
AS
    BEGIN

        SET NOCOUNT ON;

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT; 
		
		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;

        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'QuoteID = ' + CAST(@QuoteID AS VARCHAR(20));

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

                    SELECT  AnnuitantID ,
                            FirstName + ' ' + LastName AS AnnuitantName
                    FROM    qte.Annuitant
                    WHERE   QuoteID = @QuoteID;

                    COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;

    END;
GO
/****** Object:  StoredProcedure [qte].[uspGetBenefitQuote]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--DECLARE @MY_ReturnValue AS INT
--DECLARE @MY_RateVersionID AS INT
--DECLARE @MY_RateDescr AS VARCHAR(50)
--EXEC @MY_ReturnValue = qte.uspGetCurrentRateVersion @RateVersionID=@MY_RateVersionID OUTPUT, @RateDescr=@MY_RateDescr OUTPUT
--SELECT @MY_ReturnValue as ReturnCode, @MY_RateVersionID as RateVersionID, @MY_RateDescr AS RateDescr
--============================================================================
CREATE PROCEDURE [qte].[uspGetBenefitQuote]
    (
      @BenefitQuoteID INT ,
      @BenefitID INT OUTPUT ,
      @PrimaryAnnuitantID INT OUTPUT ,
      @JointAnnuitantID INT OUTPUT ,
      @PaymentMode CHAR(1) OUTPUT ,
      @BenefitAmt DECIMAL(18, 2) OUTPUT ,
      @PremiumAmt DECIMAL(18, 2) OUTPUT ,
      @FirstPaymentDate DATE OUTPUT ,
      @CertainYears INT OUTPUT ,
      @CertainMonths INT OUTPUT ,
      @ImprovementPct DECIMAL(5, 2) OUTPUT ,
      @EndDate DATE OUTPUT
    )
AS
    BEGIN

        SET NOCOUNT ON;

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT; 
		
		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;

        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'BenefitQuoteID = ' + CAST(@BenefitQuoteID AS VARCHAR(20)) + ' BenefitID = ' + CAST(@BenefitID AS VARCHAR(20))
            + ' PrimaryAnnuitantID = ' + CAST(@PrimaryAnnuitantID AS VARCHAR(20)) + ' JointAnnuitantID = ' + CAST(@JointAnnuitantID AS VARCHAR(20))
            + ' PaymentMode = ' + @PaymentMode + ' BenefitAmt = ' + CAST(@BenefitAmt AS VARCHAR(20)) + ' PremiumAmt = ' + CAST(@PremiumAmt AS VARCHAR(20))
            + ' FirstPaymentDate = ' + CAST(@FirstPaymentDate AS VARCHAR(20)) + ' CertainYears = ' + CAST(@CertainYears AS VARCHAR(20)) + ' CertainMonths = '
            + CAST(@CertainMonths AS VARCHAR(20)) + ' ImprovementPct = ' + CAST(@ImprovementPct AS VARCHAR(20)) + ' EndDate = ' + CAST(@EndDate AS VARCHAR(20));

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

                    SELECT  @BenefitID = BenefitID ,
                            @PrimaryAnnuitantID = PrimaryAnnuitantID ,
                            @JointAnnuitantID = JointAnnuitantID ,
                            @PaymentMode = PaymentMode ,
                            @BenefitAmt = BenefitAmt ,
                            @PremiumAmt = PremiumAmt ,
                            @FirstPaymentDate = FirstPaymentDate ,
                            @CertainYears = CertainYears ,
                            @CertainMonths = CertainMonths ,
                            @ImprovementPct = ImprovementPct ,
                            @EndDate = EndDate
                    FROM    qte.BenefitQuote
                    WHERE   BenefitQuoteID = @BenefitQuoteID;

                    COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;

    END;



GO
/****** Object:  StoredProcedure [qte].[uspGetBenefitQuoteGrid]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- EXEC qte.uspGetBenefitQuoteGrid @QuoteID=1
--============================================================================
CREATE PROCEDURE [qte].[uspGetBenefitQuoteGrid] ( @QuoteID INT )
AS
    BEGIN

        SET NOCOUNT ON;

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT ,
            @TransactionDate AS DATETIME;

		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;
        SET @TransactionDate = GETDATE();

        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'QuoteID = ' + CAST(@QuoteID AS VARCHAR(20));

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

;
                    WITH    cte ( TotalExpectedT, TotalExpectedN, TotalGuaranteed, BenefitQuoteID )
                              AS ( SELECT   SUM(ps.ExpectedT) AS TotalExpectedT ,
                                            SUM(ps.ExpectedN) AS TotalExpectedN ,
                                            SUM(ps.CertainAmt) AS TotalGuaranteed ,
                                            bq.BenefitQuoteID
                                   FROM     qte.BenefitQuote bq
                                            INNER JOIN qte.PaymentStream ps ON bq.BenefitQuoteID = ps.BenefitQuoteID
                                   WHERE    bq.QuoteID = @QuoteID
                                            AND bq.BenefitQuoteID = ps.BenefitQuoteID
                                   GROUP BY bq.BenefitQuoteID
                                 )
                        SELECT  bq.BenefitQuoteID ,
                                a.FirstName + ' ' + a.LastName AS AnnuitantName ,
                                ( CONVERT(INT, CONVERT(CHAR(8), @TransactionDate, 112)) - CONVERT(CHAR(8), CAST(a.DOB AS DATETIME), 112) ) / 10000 AS AnnuitantAge ,
                                b.BenefitDescr ,
                                bq.BenefitAmt ,
                                CASE bq.PaymentMode
                                  WHEN 'x' THEN 'n/a'
                                  WHEN 'M' THEN 'Monthly'
                                  WHEN 'Q' THEN 'Quarterly'
                                  WHEN 'S' THEN 'Semi-Annual'
                                  WHEN 'A' THEN 'Annual'
                                  ELSE 'n/a'
                                END AS PaymentMode ,
                                bq.FirstPaymentDate ,
                                bq.CertainYears ,
                                bq.CertainMonths ,
                                bq.ImprovementPct ,
                                bq.PremiumAmt ,
                                ps.TotalExpectedT ,
                                ps.TotalExpectedN ,
                                ps.TotalGuaranteed
                        FROM    qte.BenefitQuote bq
                                INNER JOIN qte.Annuitant a ON a.AnnuitantID = bq.PrimaryAnnuitantID
                                INNER JOIN qte.Benefit b ON b.BenefitID = bq.BenefitID
                                                            AND bq.QuoteID = @QuoteID
                                INNER JOIN cte ps ON bq.BenefitQuoteID = ps.BenefitQuoteID;

                    COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;

    END;
GO
/****** Object:  StoredProcedure [qte].[uspGetBrokerGrid]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- EXEC qte.uspGetBrokerGrid
--============================================================================
CREATE PROCEDURE [qte].[uspGetBrokerGrid]
AS
    BEGIN

        SET NOCOUNT ON;

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT ,
            @TransactionDate AS DATETIME;

		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;
        SET @TransactionDate = GETDATE();

        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'none.';

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

                    SELECT  StlmtBrokerID ,
                            FirstName ,
                            MiddleInitial ,
                            LastName ,
                            EntityName ,
                            AddrLine1 ,
                            AddrLine2 ,
                            AddrLine3 ,
                            City ,
                            StateCode ,
                            ZipCode5 ,
                            PhoneNum
                    FROM    qte.StlmtBroker;

                    COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;

    END;



GO
/****** Object:  StoredProcedure [qte].[uspGetCurrentRateVersion]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


--DECLARE @MY_ReturnValue AS INT
--DECLARE @MY_RateVersionID AS INT
--DECLARE @MY_RateDescr AS VARCHAR(50)
--EXEC @MY_ReturnValue = qte.uspGetCurrentRateVersion @RateVersionID=@MY_RateVersionID OUTPUT, @RateDescr=@MY_RateDescr OUTPUT
--SELECT @MY_ReturnValue as ReturnCode, @MY_RateVersionID as RateVersionID, @MY_RateDescr AS RateDescr
--============================================================================
CREATE PROCEDURE [qte].[uspGetCurrentRateVersion]
    (
      @RateVersionID AS INT OUTPUT ,
      @RateDescr AS VARCHAR(50) OUTPUT 
    )
AS
    BEGIN

        SET NOCOUNT ON;

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT; 
		
		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;

        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'none';

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

					;
                    WITH    CurrentRate ( RateVersionID, MaxDateCreated )
                              AS ( SELECT   RateVersionID ,
                                            MAX(DateCreated)
                                   FROM     qte.RateVersion
                                   GROUP BY RateVersionID
                                 )
                        SELECT  @RateVersionID = c.RateVersionID ,
                                @RateDescr = 'IL' + REPLACE(rv.RateDescr, '.rv', '')
                        FROM    CurrentRate c
                                INNER JOIN qte.RateVersion rv ON c.RateVersionID = rv.RateVersionID;

                    COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;

    END;



GO
/****** Object:  StoredProcedure [qte].[uspGetLifeExpExtraDeath]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--DECLARE @MY_LifeExpExtraDeathFactor AS FLOAT 
--DECLARE @MY_ExtraDeathRateOut AS FLOAT 
--DECLARE @MY_ReturnValue AS INT
--EXEC @MY_ReturnValue = qte.uspGetLifeExpExtraDeath @RatedAgeLifeExp=36.1049751793626, @RatedAge=46, @IssueAge=37, @Gender='M', @RateVersionID=1, @UseImprovement=1, @LifeExpExtraDeathFactor=@MY_LifeExpExtraDeathFactor OUTPUT, @ExtraDeathRateOut=@MY_ExtraDeathRateOut OUTPUT
--SELECT @MY_LifeExpExtraDeathFactor as LifeExpExtraDeathFactor, @MY_ExtraDeathRateOut as ExtraDeathRateOut, @MY_ReturnValue as ReturnCode
--============================================================================
CREATE PROCEDURE [qte].[uspGetLifeExpExtraDeath]
    (
      @RatedAgeLifeExp FLOAT ,
      @RatedAge INT ,
      @IssueAge INT ,
      @Gender AS CHAR(1) ,
      @RateVersionID INT ,
      @UseImprovement BIT ,
      @LifeExpExtraDeathFactor AS FLOAT OUTPUT ,
      @ExtraDeathRateOut FLOAT OUTPUT
    )
AS
    BEGIN

        SET NOCOUNT ON;

		DECLARE @StartRun AS DATETIME2(7);
		SET @StartRun = SYSDATETIME();
		DECLARE @EndRun AS DATETIME2(7);

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT; 
		
        DECLARE @ImprovementPct AS FLOAT;

		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;

        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'RatedAgeLifeExp = ' + CAST(@RatedAgeLifeExp AS VARCHAR) + ' RatedAge = ' + CAST(@RatedAge AS VARCHAR) + ' IssueAge = '
            + CAST(@IssueAge AS VARCHAR) + ' Gender = ' + @Gender + ' RateVersionID = ' + CAST(@RateVersionID AS VARCHAR);

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

                    DECLARE @GoalExtraDeathLifeExp AS FLOAT;
                    DECLARE @ExtraDeathRate AS FLOAT;
                    DECLARE @ExtraDeathRateFloor AS DECIMAL(19, 17);
                    DECLARE @ExtraDeathRateCeiling AS DECIMAL(19, 17);
                    DECLARE @Incr AS DECIMAL(19, 17);
                    DECLARE @i INT;
                    DECLARE @StartYear AS INT;
                    DECLARE @EndYear AS INT;

                    SET @StartYear = 1;
                    SET @EndYear = 121;

                    IF @UseImprovement = 1
                        BEGIN
                    
                            SELECT  @ImprovementPct = imp.ImprovementPct
                            FROM    qte.RateVersion rv
                                    INNER JOIN qte.Improvement imp ON rv.ImprovementID = imp.ImprovementID
                            WHERE   rv.RateVersionID = @RateVersionID;

                        END;
                    ELSE
                        BEGIN
                    
                            SET @ImprovementPct = 0.000;

                        END;

                    SET @GoalExtraDeathLifeExp = @RatedAgeLifeExp;

                    DECLARE @Improvement TABLE
                        (
                          AnnuityYear INT ,
                          ImprovementRate FLOAT ,
                          RatedAge TINYINT ,
                          ActualAge TINYINT
                        );
                    WITH    cte ( Number )
                              AS ( SELECT   @StartYear AS Number
                                   UNION ALL
                                   SELECT   Number + 1
                                   FROM     cte
                                   WHERE    Number < @EndYear
                                 )
                        INSERT  INTO @Improvement
                                ( AnnuityYear ,
                                  ImprovementRate ,
                                  RatedAge ,
                                  ActualAge
                                )
                                SELECT  c.Number AS AnnuityYear ,
                                        POWER(( 1 - @ImprovementPct ), ( c.Number - 1 )) AS ImprovementPct ,
                                        CASE WHEN CASE WHEN c.Number = 1 THEN @RatedAge
                                                       ELSE @RatedAge + c.Number - 1
                                                  END > 121 THEN 121
                                             ELSE CASE WHEN c.Number = 1 THEN @RatedAge
                                                       ELSE @RatedAge + c.Number - 1
                                                  END
                                        END AS RatedAge ,
                                        CASE WHEN CASE WHEN c.Number = 1 THEN @IssueAge
                                                       ELSE @IssueAge + c.Number - 1
                                                  END > 121 THEN 121
                                             ELSE CASE WHEN c.Number = 1 THEN @IssueAge
                                                       ELSE @IssueAge + c.Number - 1
                                                  END
                                        END AS ActualAge
                                FROM    cte c
                        OPTION  ( MAXRECURSION 150 );

                    DECLARE @ExtraDeathLifeExpTable TABLE
                        (
                          AnnuityYear INT ,
                          ExtraDeathLifeExpQx FLOAT ,
                          ExtraDeathLifeExpS FLOAT
                        );

                    DECLARE @TmpResult FLOAT;
                    SET @TmpResult = 0;

                    SET @ExtraDeathRateFloor = 0;
                    SET @ExtraDeathRateCeiling = 10;
                    SET @Incr = 1.0;

                    DECLARE @GoalSeekLoop AS INT;
                    DECLARE @GoalSeekLoopMax AS INT;
                    DECLARE @Iterations AS INT;

					--=======================================================
					-- Interations
					--=======================================================
                    SET @Iterations = 1;
                    SET @ExtraDeathRate = @ExtraDeathRateFloor;

                    WHILE @Iterations < 15
                        BEGIN

                            SET @GoalSeekLoop = 0;
                            SET @GoalSeekLoopMax = 100;
                            SET @ExtraDeathRate = @ExtraDeathRateFloor;

                            WHILE @GoalSeekLoop < @GoalSeekLoopMax
                                BEGIN

                                    DELETE  @ExtraDeathLifeExpTable;

                                    INSERT  INTO @ExtraDeathLifeExpTable
                                            ( AnnuityYear ,
                                              ExtraDeathLifeExpQx
                                            )
                                            SELECT  i.AnnuityYear ,
                                                    CASE WHEN i.ActualAge = 121 THEN 1
                                                         ELSE CASE WHEN m.MortalityPct * i.ImprovementRate + @ExtraDeathRate > 1 THEN 1
                                                                   ELSE m.MortalityPct * i.ImprovementRate + @ExtraDeathRate
                                                              END
                                                    END AS ExtraDeathLifeExpQx
                                            FROM    @Improvement i
                                                    INNER JOIN qte.Mortality m ON i.ActualAge = m.Age
                                                    INNER JOIN qte.MortalityHdr mh ON mh.MortalityHdrID = m.MortalityHdrID
                                                    INNER JOIN qte.RateVersion rv ON rv.MortalityHdrID = mh.MortalityHdrID
                                            WHERE   m.Gender = @Gender
                                                    AND rv.RateVersionID = @RateVersionID;

                                    UPDATE  @ExtraDeathLifeExpTable
                                    SET     ExtraDeathLifeExpS = 1 - ExtraDeathLifeExpQx
                                    WHERE   AnnuityYear = 1;

                                    SET @i = 2;
                                    WHILE @i < @EndYear
                                        BEGIN

                                            UPDATE  le1
                                            SET     ExtraDeathLifeExpS = leP.ExtraDeathLifeExpS * ( 1 - le1.ExtraDeathLifeExpQx )
                                            FROM    @ExtraDeathLifeExpTable le1
                                                    LEFT JOIN @ExtraDeathLifeExpTable leP ON le1.AnnuityYear = leP.AnnuityYear + 1
                                            WHERE   le1.AnnuityYear = @i;

                                            SET @i = @i + 1;

                                        END;

                                    SELECT  @TmpResult = SUM(ExtraDeathLifeExpS) + 0.5
                                    FROM    @ExtraDeathLifeExpTable
                                    WHERE   AnnuityYear < @EndYear;

                                    SET @GoalSeekLoop = @GoalSeekLoop + 1;

                                    IF @TmpResult < @GoalExtraDeathLifeExp
                                        BEGIN
                                            SET @ExtraDeathRate = ROUND(@ExtraDeathRate, @Iterations);
                                            SET @ExtraDeathRateFloor = @ExtraDeathRate - @Incr;
                                            SET @ExtraDeathRateCeiling = @ExtraDeathRate;
                                            SET @GoalSeekLoop = @GoalSeekLoopMax;
-- Debug/Test
--PRINT 'HIT limit: ExtraDeathRate = ' + STR(@ExtraDeathRate, @Iterations + 4, @Iterations - 1) + 
--' New floor = ' + STR(@ExtraDeathRateFloor, @Iterations + 4, @Iterations - 1) + 
--' New ceiling = ' + STR(@ExtraDeathRateCeiling, @Iterations + 4, @Iterations - 1) + 
--' Increment by ' + STR(@Incr, @Iterations + 4, @Iterations - 1);
                                        END;
                                    ELSE
                                        BEGIN
                                            SET @ExtraDeathRate = ROUND(@ExtraDeathRate, @Iterations);

                                            SET @ExtraDeathRate = @ExtraDeathRate + @Incr;
                                            SET @GoalSeekLoop = @GoalSeekLoop + 1;
-- Debug/Test
--PRINT 'Keep looking: New ED rate = ' + STR(@ExtraDeathRate, @Iterations + 4, @Iterations - 1) + 
--' Increment by ' + STR(@Incr, @Iterations + 4, @Iterations - 1);
                                        END;
                                END;

                            SET @Incr = CAST(@Incr / 10. AS DECIMAL(19, 17));

                            SET @Iterations = @Iterations + 1;

                        END;

                    SELECT  @LifeExpExtraDeathFactor = @TmpResult ,
                            @ExtraDeathRateOut = @ExtraDeathRate; 

-- Debug/Test
--PRINT 'Final result';
--PRINT STR(@ExtraDeathRate, @Iterations + 4, @Iterations - 1);

                    COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

		SET @EndRun = SYSDATETIME();
INSERT INTO qte.ProcedureLog(ProcedureName, RunStart, RunEnd)
VALUES(OBJECT_NAME(@@PROCID), @StartRun, @EndRun)

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;

    END;
GO
/****** Object:  StoredProcedure [qte].[uspGetLifeExpMultiple]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


--DECLARE @MY_ReturnValue AS INT
--EXEC @MY_ReturnValue = qte.uspGetLifeExpMultiple @RatedAgeLifeExp=36.1049751793626, @ExtraDeathRate=0.0093099332734, @RatedAge=46, @IssueAge=37, @Gender='M', @AnnuitantID=1, @UseImprovement=1, @RateVersionID=1
--SELECT @MY_ReturnValue as ReturnCode
--============================================================================
CREATE PROCEDURE [qte].[uspGetLifeExpMultiple]
    (
      @RatedAgeLifeExp FLOAT ,
      @ExtraDeathRate FLOAT ,
      @RatedAge INT ,
      @IssueAge INT ,
      @Gender CHAR(1) ,
      @AnnuitantID INT ,
      @UseImprovement BIT ,
      @RateVersionID INT
    )
AS
    BEGIN

        SET NOCOUNT ON;

		DECLARE @StartRun AS DATETIME2(7);
		SET @StartRun = SYSDATETIME();
		DECLARE @EndRun AS DATETIME2(7);

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT; 
		
        DECLARE @ImprovementPct AS FLOAT;

		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;

        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'RatedAgeLifeExp = ' + CAST(@RatedAgeLifeExp AS VARCHAR) + ' RatedAge = ' + CAST(@RatedAge AS VARCHAR) + ' IssueAge = '
            + CAST(@IssueAge AS VARCHAR) + ' Gender = ' + @Gender + ' AnnuitantID = ' + CAST(@AnnuitantID AS VARCHAR) + ' UseImprovement = '
            + CAST(@UseImprovement AS VARCHAR) + ' RateVersionID = ' + CAST(@RateVersionID AS VARCHAR);

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

                    DECLARE @GoalMultipleLifeExp AS FLOAT;
                    DECLARE @MultipleRate AS FLOAT;
                    DECLARE @MultipleRateFloor AS DECIMAL(19, 17);
                    DECLARE @MultipleRateCeiling AS DECIMAL(19, 17);
                    DECLARE @Incr AS DECIMAL(19, 17);
                    DECLARE @i INT;
                    DECLARE @StartYear AS INT;
                    DECLARE @EndYear AS INT;

                    SET @StartYear = 1;
                    SET @EndYear = 121;

					IF @UseImprovement = 1
						BEGIN
							SELECT @ImprovementPct = i.ImprovementPct
							FROM qte.RateVersion rv
							INNER JOIN qte.Improvement i ON rv.ImprovementID = i.ImprovementID
							WHERE rv.RateVersionID = @RateVersionID
						END
					ELSE
						BEGIN
							SET @ImprovementPct = 0.0;                    
						END
                    
                    SET @GoalMultipleLifeExp = @RatedAgeLifeExp;

                    DECLARE @Improvement TABLE
                        (
                          AnnuityYear INT ,
                          ImprovementRate FLOAT ,
                          RatedAge TINYINT ,
                          ActualAge TINYINT
                        );
                    WITH    cte ( Number )
                              AS ( SELECT   @StartYear AS Number
                                   UNION ALL
                                   SELECT   Number + 1
                                   FROM     cte
                                   WHERE    Number < @EndYear
                                 )
                        INSERT  INTO @Improvement
                                ( AnnuityYear ,
                                  ImprovementRate ,
                                  RatedAge ,
                                  ActualAge
                                )
                                SELECT  c.Number AS AnnuityYear ,
                                        CAST(POWER(( 1. - @ImprovementPct ), ( c.Number - 1 )) AS FLOAT) AS ImprovementRate ,
                                        CASE WHEN CASE WHEN c.Number = 1 THEN @RatedAge
                                                       ELSE @RatedAge + c.Number - 1
                                                  END > 121 THEN 121
                                             ELSE CASE WHEN c.Number = 1 THEN @RatedAge
                                                       ELSE @RatedAge + c.Number - 1
                                                  END
                                        END AS RatedAge ,
                                        CASE WHEN CASE WHEN c.Number = 1 THEN @IssueAge
                                                       ELSE @IssueAge + c.Number - 1
                                                  END > 121 THEN 121
                                             ELSE CASE WHEN c.Number = 1 THEN @IssueAge
                                                       ELSE @IssueAge + c.Number - 1
                                                  END
                                        END AS ActualAge
                                FROM    cte c
                        OPTION  ( MAXRECURSION 150 );

                    DECLARE @TmpResult FLOAT;
                    SET @TmpResult = 0;

                    SET @MultipleRateFloor = 1;
                    SET @MultipleRateCeiling = 10;
                    SET @Incr = 1.0;

                    DECLARE @GoalSeekLoop AS INT;
                    DECLARE @GoalSeekLoopMax AS INT;
                    DECLARE @Iterations AS INT;

					--=======================================================
					-- Interations
					--=======================================================
                    SET @Iterations = 1;
                    SET @MultipleRate = @MultipleRateFloor;

                    WHILE @Iterations < 15
                        BEGIN

                            SET @GoalSeekLoop = 0;
                            SET @GoalSeekLoopMax = 100;
                            SET @MultipleRate = @MultipleRateFloor;

                            WHILE @GoalSeekLoop < @GoalSeekLoopMax
                                BEGIN


TRUNCATE TABLE qte.LifeExpMultiple
                                    --DELETE  qte.LifeExpMultiple
                                    --WHERE   AnnuitantID = @AnnuitantID
                                    --        AND UseImprovement = @UseImprovement;

                                    INSERT  INTO qte.LifeExpMultiple
                                            ( AnnuitantID ,
                                              UseImprovement ,
                                              AnnuityYear ,
                                              LifeExpMultipleQx
											)
                                            SELECT  @AnnuitantID ,
                                                    @UseImprovement ,
                                                    i.AnnuityYear ,
                                                    CASE WHEN i.ActualAge = 121 THEN 1
                                                         ELSE CASE WHEN ( m.MortalityPct * i.ImprovementRate * @MultipleRate ) + ( @ExtraDeathRate * 0.5 ) > 1
                                                                   THEN 1
                                                                   ELSE CAST(( CAST(m.MortalityPct AS FLOAT) * i.ImprovementRate * @MultipleRate ) AS FLOAT) + CAST(( @ExtraDeathRate * 0.5 ) AS FLOAT)
                                                              END
                                                    END AS MultipleQx
                                            FROM    @Improvement i
                                                    INNER JOIN qte.Mortality m ON i.ActualAge = m.Age
                                                    INNER JOIN qte.MortalityHdr mh ON mh.MortalityHdrID = m.MortalityHdrID
                                                    INNER JOIN qte.RateVersion rv ON rv.MortalityHdrID = mh.MortalityHdrID
                                            WHERE   m.Gender = @Gender
                                                    AND rv.RateVersionID = @RateVersionID;

                                    UPDATE  qte.LifeExpMultiple
                                    SET     LifeExpMultipleS = 1 - LifeExpMultipleQx
                                    WHERE   AnnuityYear = 1
                                            AND AnnuitantID = @AnnuitantID
                                            AND UseImprovement = @UseImprovement;




;WITH cte (AnnuitantID, UseImprovement, AnnuityYear, LifeExpMultipleS, LifeExpMultipleQx) AS 
(
	SELECT AnnuitantID, UseImprovement, AnnuityYear, LifeExpMultipleS, LifeExpMultipleQx
	FROM qte.LifeExpMultiple
    WHERE   AnnuitantID = @AnnuitantID
            AND UseImprovement = @UseImprovement
)
, cte2 (AnnuitantID, UseImprovement, AnnuityYear, LifeExpMultipleS, LifeExpMultipleQx) AS 
(
	SELECT AnnuitantID, UseImprovement, AnnuityYear, LifeExpMultipleS, LifeExpMultipleQx
	FROM cte
	WHERE AnnuityYear = 1

	UNION ALL
    
	SELECT cte.AnnuitantID, cte.UseImprovement, cte.AnnuityYear
	, cte2.LifeExpMultipleS * ( 1 - cte.LifeExpMultipleQx ) AS LifeExpMultipleS
	, cte.LifeExpMultipleQx
	FROM cte 
	INNER JOIN cte2 ON cte.AnnuityYear = cte2.AnnuityYear + 1
                                            AND cte.AnnuitantID = cte2.AnnuitantID
                                            AND cte.UseImprovement = cte2.UseImprovement
)	
--SELECT *
--FROM cte2
--OPTION (MAXRECURSION 121)

UPDATE l
SET LifeExpMultipleS = cte2.LifeExpMultipleS
FROM qte.LifeExpMultiple l
INNER JOIN cte2 ON cte2.AnnuityYear = l.AnnuityYear
WHERE l.AnnuityYear > 1
        AND l.AnnuitantID = cte2.AnnuitantID
        AND l.UseImprovement = cte2.UseImprovement
OPTION (MAXRECURSION 121)

                                    --SET @i = 2;
                                    --WHILE @i < @EndYear
                                    --    BEGIN

                                    --        UPDATE  le1
                                    --        SET     LifeExpMultipleS = leP.LifeExpMultipleS * ( 1 - le1.LifeExpMultipleQx )
                                    --        FROM    qte.LifeExpMultiple le1
                                    --                LEFT JOIN qte.LifeExpMultiple leP ON le1.AnnuityYear = leP.AnnuityYear + 1
                                    --                                                     AND le1.AnnuitantID = leP.AnnuitantID
                                    --                                                     AND le1.UseImprovement = leP.UseImprovement
                                    --        WHERE   le1.AnnuityYear = @i
                                    --                AND le1.AnnuitantID = @AnnuitantID
                                    --                AND le1.UseImprovement = @UseImprovement;

                                    --        SET @i = @i + 1;

                                    --    END;

                                    SELECT  @TmpResult = SUM(LifeExpMultipleS) + 0.5
                                    FROM    qte.LifeExpMultiple
                                    WHERE   AnnuityYear < @EndYear
                                            AND AnnuitantID = @AnnuitantID
                                            AND UseImprovement = @UseImprovement;

                                    SET @GoalSeekLoop = @GoalSeekLoop + 1;

                                    IF @TmpResult < @GoalMultipleLifeExp
                                        BEGIN
                                            SET @MultipleRate = ROUND(@MultipleRate, @Iterations);
                                            SET @MultipleRateFloor = @MultipleRate - @Incr;
                                            SET @MultipleRateCeiling = @MultipleRate;
                                            SET @GoalSeekLoop = @GoalSeekLoopMax;
-- Debug/Test
--PRINT 'HIT limit: MultipleRate = ' + STR(@MultipleRate, @Iterations + 4, @Iterations - 1) + 
--' New floor = ' + STR(@MultipleRateFloor, @Iterations + 4, @Iterations - 1) + 
--' New ceiling = ' + STR(@MultipleRateCeiling, @Iterations + 4, @Iterations - 1) + 
--' Increment by ' + STR(@Incr, @Iterations + 4, @Iterations - 1);
                                        END;
                                    ELSE
                                        BEGIN
                                            SET @MultipleRate = ROUND(@MultipleRate, @Iterations);
                                            SET @MultipleRate = @MultipleRate + @Incr;
                                            SET @GoalSeekLoop = @GoalSeekLoop + 1;
-- Debug/Test
--PRINT 'Keep looking: New Multiple rate = ' + STR(@MultipleRate, @Iterations + 4, @Iterations - 1) + 
--' Increment by ' + STR(@Incr, @Iterations + 4, @Iterations - 1);
                                        END;
                                END;

                            SET @Incr = CAST(@Incr / 10. AS DECIMAL(19, 17));

                            SET @Iterations = @Iterations + 1;

                        END;

--SELECT * FROM    qte.LifeExpMultiple 

-- Debug/Test
--PRINT 'Final result';
--PRINT STR(@MultipleRate, @Iterations + 4, @Iterations - 1);




                    COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

		SET @EndRun = SYSDATETIME();
INSERT INTO qte.ProcedureLog(ProcedureName, RunStart, RunEnd)
VALUES(OBJECT_NAME(@@PROCID), @StartRun, @EndRun)

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;

    END;



GO
/****** Object:  StoredProcedure [qte].[uspGetLifeExpRatedAge]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--DECLARE @MY_LifeExpRatedAgeFactor AS FLOAT 
--DECLARE @MY_ReturnValue AS INT
--EXEC @MY_ReturnValue = qte.uspGetLifeExpRatedAge @RatedAge=46, @IssueAge=37, @Gender='M', @RateVersionID=1, @UseImprovement=1, @LifeExpRatedAgeFactor=@MY_LifeExpRatedAgeFactor OUTPUT
--SELECT @MY_LifeExpRatedAgeFactor as LifeExpRatedAgeFactor, @MY_ReturnValue as ReturnCode
--============================================================================
CREATE PROCEDURE [qte].[uspGetLifeExpRatedAge]
    (
      @RatedAge INT ,
      @IssueAge INT ,
      @Gender AS CHAR(1) ,
      @RateVersionID INT ,
      @UseImprovement BIT ,
      @LifeExpRatedAgeFactor AS FLOAT OUTPUT 
    )
AS
    BEGIN

        SET NOCOUNT ON;

		DECLARE @StartRun AS DATETIME2(7);
		SET @StartRun = SYSDATETIME();
		DECLARE @EndRun AS DATETIME2(7);

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT; 
		
        DECLARE @ImprovementPct AS FLOAT;

		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;

        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'RatedAge = ' + CAST(@RatedAge AS VARCHAR) + ' IssueAge = ' + CAST(@IssueAge AS VARCHAR) + ' Gender = ' + @Gender + ' RateVersionID = ' + CAST(@RateVersionID AS VARCHAR);

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

                    IF @UseImprovement = 1
                        BEGIN
                    
                            SELECT  @ImprovementPct = imp.ImprovementPct
                            FROM    qte.RateVersion rv
                                    INNER JOIN qte.Improvement imp ON rv.ImprovementID = imp.ImprovementID
                            WHERE   rv.RateVersionID = @RateVersionID;

                        END;
                    ELSE
                        BEGIN
                    
                            SET @ImprovementPct = 0.000;

                        END;

                    DECLARE @Improvement TABLE
                        (
                          AnnuityYear INT ,
                          ImprovementRate FLOAT ,
                          RatedAge TINYINT ,
                          ActualAge TINYINT
                        );

                    DECLARE @LifeExp TABLE
                        (
                          AnnuityYear INT ,
                          LifeExpQx FLOAT ,
                          LifeExpS FLOAT
                        );

                    DECLARE @StartYear AS INT;
                    DECLARE @EndYear AS INT;
                    SET @StartYear = 1;
                    SET @EndYear = 121;
                    WITH    cte ( Number )
                              AS ( SELECT   @StartYear AS Number
                                   UNION ALL
                                   SELECT   Number + 1
                                   FROM     cte
                                   WHERE    Number < @EndYear
                                 )
                        INSERT  INTO @Improvement
                                ( AnnuityYear ,
                                  ImprovementRate ,
                                  RatedAge ,
                                  ActualAge
                                )
                                SELECT  c.Number AS AnnuityYear ,
                                        POWER(( 1 - @ImprovementPct ), ( c.Number - 1 )) AS ImprovementRate ,
                                        CASE WHEN CASE WHEN c.Number = 1 THEN @RatedAge
                                                       ELSE @RatedAge + c.Number - 1
                                                  END > 121 THEN 121
                                             ELSE CASE WHEN c.Number = 1 THEN @RatedAge
                                                       ELSE @RatedAge + c.Number - 1
                                                  END
                                        END AS RatedAge ,
                                        CASE WHEN CASE WHEN c.Number = 1 THEN @IssueAge
                                                       ELSE @IssueAge + c.Number - 1
                                                  END > 121 THEN 121
                                             ELSE CASE WHEN c.Number = 1 THEN @IssueAge
                                                       ELSE @IssueAge + c.Number - 1
                                                  END
                                        END AS ActualAge
                                FROM    cte c
                        OPTION  ( MAXRECURSION 150 );

                    INSERT  INTO @LifeExp
                            ( AnnuityYear ,
                              LifeExpQx
                            )
                            SELECT  i.AnnuityYear ,
                                    CASE WHEN i.RatedAge = 121 THEN 1
                                         ELSE m.MortalityPct * i.ImprovementRate
                                    END AS LifeExpQx
                            FROM    @Improvement i
                                    INNER JOIN qte.Mortality m ON i.RatedAge = m.Age
                                    INNER JOIN qte.MortalityHdr mh ON mh.MortalityHdrID = m.MortalityHdrID
                                    INNER JOIN qte.RateVersion rv ON rv.MortalityHdrID = mh.MortalityHdrID
                            WHERE   m.Gender = @Gender
                                    AND rv.RateVersionID = @RateVersionID;

                    UPDATE  @LifeExp
                    SET     LifeExpS = 1 - LifeExpQx
                    WHERE   AnnuityYear = 1;




----SELECT nt.Number, leP.LifeExpS * ( 1 - le1.LifeExpQx )
--UPDATE  le1
--SET     LifeExpS = leP.LifeExpS * ( 1 - le1.LifeExpQx )
--FROM    @LifeExp le1
--        LEFT JOIN @LifeExp leP ON le1.AnnuityYear = leP.AnnuityYear + 1
--INNER JOIN qte.NumbersTable nt ON le1.AnnuityYear = nt.Number
--WHERE nt.Number BETWEEN 2 AND 120

;WITH cte AS 
(
	SELECT AnnuityYear, LifeExpS, LifeExpQx 
	FROM @LifeExp
)
, cte2 (AnnuityYear, LifeExpS, LifeExpQx) AS 
(
	SELECT AnnuityYear, LifeExpS, LifeExpQx
	FROM cte
	WHERE cte.AnnuityYear = 1

	UNION ALL
    
	SELECT cte.AnnuityYear
--	, cte.LifeExpS
	, cte2.LifeExpS * ( 1 - cte.LifeExpQx) AS LifeExpS
	, cte.LifeExpQx
	FROM cte 
	INNER JOIN cte2 ON cte.AnnuityYear = cte2.AnnuityYear + 1
)	

--SELECT cte2.AnnuityYear, cte2.LifeExpQx, cte2.LifeExpS
--FROM cte2	
--OPTION (MAXRECURSION 122)

UPDATE l
SET LifeExpS = cte2.LifeExpS
FROM @LifeExp l
INNER JOIN cte2 ON cte2.AnnuityYear = l.AnnuityYear
WHERE l.AnnuityYear > 1
OPTION (MAXRECURSION 122)


                    --DECLARE @i INT;
                    --SET @i = 2;
                    --WHILE @i < @EndYear
                    --    BEGIN

                    --        UPDATE  le1
                    --        SET     LifeExpS = leP.LifeExpS * ( 1 - le1.LifeExpQx )
                    --        FROM    @LifeExp le1
                    --                LEFT JOIN @LifeExp leP ON le1.AnnuityYear = leP.AnnuityYear + 1
                    --        WHERE   le1.AnnuityYear = @i;

                    --        SET @i = @i + 1;
                    --    END;


--SELECT * FROM @LifeExp

                    SELECT  @LifeExpRatedAgeFactor = SUM(LifeExpS) + 0.5
                    FROM    @LifeExp
                    WHERE   AnnuityYear < @EndYear;

                    COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

		SET @EndRun = SYSDATETIME();
INSERT INTO qte.ProcedureLog(ProcedureName, RunStart, RunEnd)
VALUES(OBJECT_NAME(@@PROCID), @StartRun, @EndRun)


					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;

    END;
GO
/****** Object:  StoredProcedure [qte].[uspGetPaymentValueLifeAndCertain]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




--DECLARE @MY_ReturnValue AS INT
--DECLARE @MY_PaymentValue AS DECIMAL(19,2)
--EXEC @MY_ReturnValue = qte.uspGetPaymentValueLifeAndCertain @BenefitQuoteID=1, @UseCertainComponent=1, @UseContingentComponent=1, @PaymentValue=@MY_PaymentValue OUTPUT
--SELECT @MY_ReturnValue as ReturnCode, @MY_PaymentValue as PaymentValue
--============================================================================
CREATE PROCEDURE [qte].[uspGetPaymentValueLifeAndCertain]
    (
      @BenefitQuoteID AS INT ,
      @UseCertainComponent AS BIT ,
      @UseContingentComponent AS BIT ,
      @PaymentValue AS DECIMAL(19, 2) OUTPUT
    )
AS
    BEGIN

        SET NOCOUNT ON;

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT; 
		
        DECLARE @PurchaseDate AS DATE;
        DECLARE @FirstPaymentDate AS DATE;
        DECLARE @PaymentMode AS INT;
        DECLARE @CertainYears AS INT;
        DECLARE @CertainMonths AS INT;
        DECLARE @LastCertainPaymentDate AS DATE;
        DECLARE @LastContingentPaymentDate AS DATE;
        DECLARE @BenefitAmt AS DECIMAL(19, 10);
        DECLARE @ImprovementPct AS DECIMAL(19, 12);
        DECLARE @AnnuitantID AS INT;
        DECLARE @RateVersionID AS INT;

		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;

        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'BenefitQuoteID = ' + CAST(@BenefitQuoteID AS VARCHAR(20));

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

                    SELECT  @PurchaseDate = q.PurchaseDate ,
                            @FirstPaymentDate = bq.FirstPaymentDate ,
                            @PaymentMode = CASE bq.PaymentMode
                                             WHEN 'A' THEN 12
                                             WHEN 'S' THEN 6
                                             WHEN 'Q' THEN 3
                                             WHEN 'M' THEN 1
                                             WHEN 'O' THEN 12
                                             ELSE 12
                                           END ,
                            @CertainYears = bq.CertainYears ,
                            @CertainMonths = bq.CertainMonths ,
                            @BenefitAmt = bq.BenefitAmt ,
                            @ImprovementPct = bq.ImprovementPct / 100. ,
                            @AnnuitantID = bq.PrimaryAnnuitantID ,
                            @RateVersionID = q.RateVersionID
                    FROM    qte.BenefitQuote bq
                            INNER JOIN qte.Quote q ON bq.QuoteID = q.QuoteID
                    WHERE   bq.BenefitQuoteID = @BenefitQuoteID;

                    SET @LastCertainPaymentDate = '1/1/0001';
                    SET @LastContingentPaymentDate = '12/31/9999';
                    IF @UseCertainComponent = 1
                        AND @UseContingentComponent = 1
                        SET @LastCertainPaymentDate = DATEADD(MONTH, ( @CertainYears * 12 ) + @CertainMonths - 1, @FirstPaymentDate);

                    IF @UseCertainComponent = 1
                        AND @UseContingentComponent = 0
                        SET @LastCertainPaymentDate = DATEADD(MONTH, ( @CertainYears * 12 ), @FirstPaymentDate);

					-- Using the last certain payment date as last 
                    IF @UseCertainComponent = 0
                        AND @UseContingentComponent = 1
                        SET @LastContingentPaymentDate = DATEADD(MONTH, ( @CertainYears * 12 ), @FirstPaymentDate);

--SELECT @LastCertainPaymentDate, @LastContingentPaymentDate

                    DECLARE @PaymentStream AS TABLE
                        (
                          AnnuityYear INT ,
                          AnnuityMonth INT ,
                          AnnuityAccumMonth INT ,
                          AnnuityDate DATE ,
                          MakePayment BIT ,
                          CertainAmt FLOAT ,
                          ContingentAmt FLOAT ,
                          PaymentStreamS FLOAT ,
                          PaymentValue FLOAT
                        );
                    WITH    bs ( Number )
                              AS ( SELECT   0 AS Number
                                   UNION ALL
                                   SELECT   Number + 1
                                   FROM     bs
                                   WHERE    Number < 1440
                                 )
                        INSERT  INTO @PaymentStream
                                ( AnnuityYear ,
                                  AnnuityMonth ,
                                  AnnuityAccumMonth ,
                                  AnnuityDate ,
                                  MakePayment
                                )
                                SELECT  ( ( Number - 1 ) / 12 ) + 1 AS AnnuityYear ,
                                        CASE WHEN Number = 0 THEN 0
                                             ELSE CASE WHEN ( Number % 12 ) = 0 THEN 12
                                                       ELSE ( Number % 12 )
                                                  END
                                        END AS AnnuityMonth ,
                                        Number AS AnnuityAccumMonth ,
                                        DATEADD(MONTH, ( ( ( Number - 1 ) / 12 ) * 12 ) + CASE WHEN Number = 0 THEN 0
                                                                                               ELSE CASE WHEN ( Number % 12 ) = 0 THEN 12
                                                                                                         ELSE ( Number % 12 )
                                                                                                    END
                                                                                          END, @PurchaseDate) AS AnnuityDate ,
                                        CASE WHEN @FirstPaymentDate >= DATEADD(MONTH,
                                                                               ( ( ( Number - 1 ) / 12 ) * 12 ) + CASE WHEN Number = 0 THEN 0
                                                                                                                       ELSE CASE WHEN ( Number % 12 ) = 0
                                                                                                                                 THEN 12
                                                                                                                                 ELSE ( Number % 12 )
                                                                                                                            END
                                                                                                                  END, @PurchaseDate)
                                                  AND @FirstPaymentDate < DATEADD(MONTH,
                                                                                   ( ( ( Number - 1 ) / 12 ) * 12 ) + CASE WHEN Number = 0 THEN 0
                                                                                                                           ELSE CASE WHEN ( Number % 12 ) = 0
                                                                                                                                     THEN 12
                                                                                                                                     ELSE ( Number % 12 )
                                                                                                                                END
                                                                                                                      END + 1, @PurchaseDate) THEN 1
                                             ELSE 0
                                        END AS MakePayment
                                FROM    bs
                        OPTION  ( MAXRECURSION 1440 );

                    SELECT  @FirstPaymentDate = AnnuityDate
                    FROM    @PaymentStream
                    WHERE   MakePayment = 1;

                    UPDATE  @PaymentStream
                    SET     MakePayment = CASE WHEN ABS(DATEDIFF(MONTH, AnnuityDate, @FirstPaymentDate)) % @PaymentMode = 0 THEN 1
                                               ELSE 0
                                          END
                    WHERE   AnnuityDate > @FirstPaymentDate;

--DECLARE @YearOffset AS INT
--SET @YearOffset = YEAR(@FirstPaymentDate) - YEAR(@PurchaseDate) + 1

                    IF @UseCertainComponent = 1
                        BEGIN



--SELECT @BenefitAmt * CAST(POWER(1 + @ImprovementPct, psc.AnnuityYear - 1) AS FLOAT)
--, @BenefitAmt * CAST(POWER(1 + @ImprovementPct, psc.AnnuityYear - @YearOffset) AS FLOAT)
--, DATEDIFF(MONTH, @FirstPaymentDate, psc.AnnuityDate)
--, DATEDIFF(MONTH, @FirstPaymentDate, psc.AnnuityDate) / 12
--, DATEDIFF(MONTH, @FirstPaymentDate, psc.AnnuityDate) % 12
--, psc.AnnuityYear - 1
--, psc.AnnuityDate
--, YEAR(@FirstPaymentDate) - YEAR(@PurchaseDate)
----ELSE @BenefitAmt * CAST(POWER(1 + @ImprovementPct, YEAR(@FirstPaymentDate) - YEAR(psc.AnnuityDate) - 2) AS FLOAT)
--FROM    @PaymentStream psc
--        LEFT JOIN @PaymentStream psp ON psp.AnnuityDate = DATEADD(YEAR, -1, psc.AnnuityDate);




                            UPDATE  psc
                            SET     CertainAmt = CASE WHEN @UseCertainComponent = 1
                                                      THEN CASE WHEN psc.MakePayment = 1
                                                                     AND DATEADD(MONTH, ( @CertainYears * 12 ) + @CertainMonths, @FirstPaymentDate) > psc.AnnuityDate
                                                                     AND @LastCertainPaymentDate >= psc.AnnuityDate
                                                                THEN CASE WHEN psc.AnnuityYear = 1 THEN @BenefitAmt

--                                                                          ELSE @BenefitAmt * CAST(POWER(1 + @ImprovementPct, psc.AnnuityYear - @YearOffset) AS FLOAT)
                                                                          ELSE @BenefitAmt * CAST(POWER(1 + @ImprovementPct, DATEDIFF(MONTH, @FirstPaymentDate, psc.AnnuityDate) / 12) AS FLOAT)

																		  --ELSE @BenefitAmt * CAST(POWER(1 + @ImprovementPct, YEAR(@FirstPaymentDate) - YEAR(psc.AnnuityDate) - 2) AS FLOAT)

                                                                     END
                                                                ELSE 0
                                                           END
                                                      ELSE 0
                                                 END ,
                                    ContingentAmt = CASE WHEN @UseContingentComponent = 1
                                                         THEN CASE WHEN psc.MakePayment = 1
                                                                        AND DATEADD(MONTH, ( @CertainYears * 12 ) + @CertainMonths, @FirstPaymentDate) <= psc.AnnuityDate
                                                                        AND @LastCertainPaymentDate < psc.AnnuityDate
                                                                   THEN CASE WHEN psc.AnnuityYear = 1 THEN @BenefitAmt
--                                                                             ELSE @BenefitAmt * CAST(POWER(1 + @ImprovementPct, psc.AnnuityYear - @YearOffset) AS FLOAT)
                                                                             ELSE @BenefitAmt * CAST(POWER(1 + @ImprovementPct, DATEDIFF(MONTH, @FirstPaymentDate, psc.AnnuityDate) / 12) AS FLOAT)
                                                                        END
                                                                   ELSE 0
                                                              END
                                                         ELSE 0
                                                    END
                            FROM    @PaymentStream psc
                                    LEFT JOIN @PaymentStream psp ON psp.AnnuityDate = DATEADD(YEAR, -1, psc.AnnuityDate);

                        END;
                    IF @UseCertainComponent = 0
                        BEGIN

                            UPDATE  psc
                            SET     CertainAmt = 0 ,
                                    ContingentAmt = CASE WHEN psc.MakePayment = 1
                                                              AND DATEADD(MONTH, ( @CertainYears * 12 ) + @CertainMonths, @FirstPaymentDate) > psc.AnnuityDate
                                                              AND @LastContingentPaymentDate > psc.AnnuityDate
                                                         THEN CASE WHEN psc.AnnuityYear = 1 THEN @BenefitAmt
                                                                   ELSE @BenefitAmt * CAST(POWER(1 + @ImprovementPct, DATEDIFF(MONTH, @FirstPaymentDate, psc.AnnuityDate) / 12) AS FLOAT)
                                                              END
                                                         ELSE 0
                                                    END
                            FROM    @PaymentStream psc
                                    LEFT JOIN @PaymentStream psp ON psp.AnnuityDate = DATEADD(YEAR, -1, psc.AnnuityDate);

                        END;
                    
                    UPDATE  @PaymentStream
                    SET     PaymentStreamS = 1
                    WHERE   AnnuityYear = 1
                            AND AnnuityMonth = 0;

                    UPDATE  psc
                    SET     PaymentStreamS = CAST(POWER(1. - lem.LifeExpMultipleQx, 1. / 12.) AS FLOAT)
                    FROM    @PaymentStream psc
                            INNER JOIN qte.LifeExpMultiple lem ON psc.AnnuityYear = lem.AnnuityYear
                    WHERE   psc.AnnuityYear = 1
                            AND psc.AnnuityMonth = 1
                            AND lem.AnnuitantID = @AnnuitantID
                            AND lem.UseImprovement = CASE WHEN @ImprovementPct > 0 THEN 1
                                                          ELSE 0
                                                     END;

                    DECLARE @i INT;
                    SET @i = 2;
                    WHILE @i <= 1441
                        BEGIN

                            UPDATE  psc
                            SET     PaymentStreamS = CAST(POWER(1. - lem.LifeExpMultipleQx, 1. / 12.) * psp.PaymentStreamS AS FLOAT)
                            FROM    @PaymentStream psc
                                    INNER JOIN qte.LifeExpMultiple lem ON psc.AnnuityYear = lem.AnnuityYear
                                    LEFT JOIN @PaymentStream psp ON psp.AnnuityAccumMonth = psc.AnnuityAccumMonth - 1
                            WHERE   psc.AnnuityAccumMonth = @i
                                    AND lem.AnnuitantID = @AnnuitantID
                                    AND lem.UseImprovement = CASE WHEN @ImprovementPct > 0 THEN 1
                                                                  ELSE 0
                                                             END;

                            SET @i = @i + 1;
                        END;

                    IF @UseCertainComponent = 1
                        AND @UseContingentComponent = 1
                        BEGIN
                    
                            UPDATE  psc
                            SET     psc.PaymentValue = ( psc.CertainAmt * si.SpotInterestVx ) + ( psc.ContingentAmt * psc.PaymentStreamS * si.SpotInterestVx )
                            FROM    @PaymentStream psc
                                    INNER JOIN qte.SpotInterest si ON psc.AnnuityYear = si.AnnuityYear
                                                                      AND psc.AnnuityMonth = si.AnnuityMonth
                            WHERE   si.RateVersionID = @RateVersionID;

                        END;
                    IF @UseCertainComponent = 1
                        AND @UseContingentComponent = 0
                        BEGIN
                    
                            UPDATE  psc
                            SET     psc.PaymentValue = ( psc.CertainAmt * si.SpotInterestVx )
                            FROM    @PaymentStream psc
                                    INNER JOIN qte.SpotInterest si ON psc.AnnuityYear = si.AnnuityYear
                                                                      AND psc.AnnuityMonth = si.AnnuityMonth
                            WHERE   si.RateVersionID = @RateVersionID;

                        END;
                    IF @UseCertainComponent = 0
                        AND @UseContingentComponent = 1
                        BEGIN
                    
                            UPDATE  psc
                            SET     psc.PaymentValue = ( psc.ContingentAmt * psc.PaymentStreamS * si.SpotInterestVx )
                            FROM    @PaymentStream psc
                                    INNER JOIN qte.SpotInterest si ON psc.AnnuityYear = si.AnnuityYear
                                                                      AND psc.AnnuityMonth = si.AnnuityMonth
                            WHERE   si.RateVersionID = @RateVersionID;

                        END;

                    SELECT  @PaymentValue = SUM(psc.PaymentValue) / 0.95
                    FROM    @PaymentStream psc;

--SELECT * FROM @PaymentStream
--SELECT @PaymentValue AS GetFromLifeAndCertain

                    COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;

    END;





GO
/****** Object:  StoredProcedure [qte].[uspGetPaymentValueLumpSum]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


--DECLARE @out_ReturnValue AS INT
--DECLARE @out_PaymentValue AS DECIMAL(19,2)
--EXEC @out_ReturnValue = qte.uspGetPaymentValueLumpSum @BenefitQuoteID=1, @PaymentValue=@out_PaymentValue OUTPUT
--SELECT @out_ReturnValue as ReturnCode, @out_PaymentValue as PaymentValue
--============================================================================
CREATE PROCEDURE [qte].[uspGetPaymentValueLumpSum]
    (
      @BenefitQuoteID AS INT ,
      @PaymentValue AS DECIMAL(19, 2) OUTPUT
    )
AS
    BEGIN

        SET NOCOUNT ON;

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT; 
		
        DECLARE @RateVersionID AS INT;
        DECLARE @AnnuitantID AS INT;
        DECLARE @PurchaseDate AS DATE;
        DECLARE @BenefitAmt AS DECIMAL(19, 10);
        DECLARE @FirstPaymentDate AS DATE;

        DECLARE @ImprovementPct AS DECIMAL(19, 12);

		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;

        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'BenefitQuoteID = ' + CAST(@BenefitQuoteID AS VARCHAR(20));

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

                    SELECT  @PurchaseDate = q.PurchaseDate ,
                            @FirstPaymentDate = bq.FirstPaymentDate ,
                            @BenefitAmt = bq.BenefitAmt ,
                            @AnnuitantID = bq.PrimaryAnnuitantID ,
                            @ImprovementPct = bq.ImprovementPct / 100. ,
                            @RateVersionID = q.RateVersionID
                    FROM    qte.BenefitQuote bq
                            INNER JOIN qte.Quote q ON bq.QuoteID = q.QuoteID
                    WHERE   bq.BenefitQuoteID = @BenefitQuoteID;

                    DECLARE @PaymentStream AS TABLE
                        (
                          AnnuityYear INT ,
                          AnnuityMonth INT ,
                          AnnuityAccumMonth INT ,
                          AnnuityDate DATE ,
                          MakePayment BIT ,
                          CertainAmt FLOAT ,
                          ContingentAmt FLOAT ,
                          PaymentStreamS FLOAT ,
                          PaymentValue FLOAT
                        );
                    WITH    bs ( Number )
                              AS ( SELECT   0 AS Number
                                   UNION ALL
                                   SELECT   Number + 1
                                   FROM     bs
                                   WHERE    Number < 1440
                                 )
                        INSERT  INTO @PaymentStream
                                ( CertainAmt ,
                                  ContingentAmt ,
                                  AnnuityYear ,
                                  AnnuityMonth ,
                                  AnnuityAccumMonth ,
                                  AnnuityDate ,
                                  MakePayment
                                )
                                SELECT  0.0 ,
                                        0.0 ,
                                        ( ( Number - 1 ) / 12 ) + 1 AS AnnuityYear ,
                                        CASE WHEN Number = 0 THEN 0
                                             ELSE CASE WHEN ( Number % 12 ) = 0 THEN 12
                                                       ELSE ( Number % 12 )
                                                  END
                                        END AS AnnuityMonth ,
                                        Number AS AnnuityAccumMonth ,
                                        DATEADD(MONTH, ( ( ( Number - 1 ) / 12 ) * 12 ) + CASE WHEN Number = 0 THEN 0
                                                                                               ELSE CASE WHEN ( Number % 12 ) = 0 THEN 12
                                                                                                         ELSE ( Number % 12 )
                                                                                                    END
                                                                                          END, @PurchaseDate) AS AnnuityDate ,
                                        CASE WHEN @FirstPaymentDate >= DATEADD(MONTH,
                                                                               ( ( ( Number - 1 ) / 12 ) * 12 ) + CASE WHEN Number = 0 THEN 0
                                                                                                                       ELSE CASE WHEN ( Number % 12 ) = 0
                                                                                                                                 THEN 12
                                                                                                                                 ELSE ( Number % 12 )
                                                                                                                            END
                                                                                                                  END, @PurchaseDate)
                                                  AND @FirstPaymentDate < DATEADD(MONTH,
                                                                                  ( ( ( Number - 1 ) / 12 ) * 12 ) + CASE WHEN Number = 0 THEN 0
                                                                                                                          ELSE CASE WHEN ( Number % 12 ) = 0
                                                                                                                                    THEN 12
                                                                                                                                    ELSE ( Number % 12 )
                                                                                                                               END
                                                                                                                     END + 1, @PurchaseDate) THEN 1
                                             ELSE 0
                                        END AS MakePayment
                                FROM    bs
                        OPTION  ( MAXRECURSION 1440 );

                    SELECT  @FirstPaymentDate = AnnuityDate
                    FROM    @PaymentStream
                    WHERE   MakePayment = 1;

                    UPDATE  @PaymentStream
                    SET     CertainAmt = @BenefitAmt
                    WHERE   MakePayment = 1;

                    UPDATE  @PaymentStream
                    SET     PaymentStreamS = 1
                    WHERE   AnnuityYear = 1
                            AND AnnuityMonth = 0;

                    UPDATE  psc
                    SET     PaymentStreamS = CAST(POWER(1. - lem.LifeExpMultipleQx, 1. / 12.) AS FLOAT)
                    FROM    @PaymentStream psc
                            INNER JOIN qte.LifeExpMultiple lem ON psc.AnnuityYear = lem.AnnuityYear
                    WHERE   psc.AnnuityYear = 1
                            AND psc.AnnuityMonth = 1
                            AND lem.AnnuitantID = @AnnuitantID
                            AND lem.UseImprovement = CASE WHEN @ImprovementPct > 0 THEN 1
                                                          ELSE 0
                                                     END;

                    DECLARE @i INT;
                    SET @i = 2;
                    WHILE @i <= 1441
                        BEGIN

                            UPDATE  psc
                            SET     PaymentStreamS = CAST(POWER(1. - lem.LifeExpMultipleQx, 1. / 12.) * psp.PaymentStreamS AS FLOAT)
                            FROM    @PaymentStream psc
                                    INNER JOIN qte.LifeExpMultiple lem ON psc.AnnuityYear = lem.AnnuityYear
                                    LEFT JOIN @PaymentStream psp ON psp.AnnuityAccumMonth = psc.AnnuityAccumMonth - 1
                            WHERE   psc.AnnuityAccumMonth = @i
                                    AND lem.AnnuitantID = @AnnuitantID
                                    AND lem.UseImprovement = CASE WHEN @ImprovementPct > 0 THEN 1
                                                                  ELSE 0
                                                             END;
                            SET @i = @i + 1;
                        END;

                    UPDATE  psc
                    SET     psc.PaymentValue = ( psc.CertainAmt * si.SpotInterestVx ) + ( psc.ContingentAmt * psc.PaymentStreamS * si.SpotInterestVx )
                    FROM    @PaymentStream psc
                            INNER JOIN qte.SpotInterest si ON psc.AnnuityYear = si.AnnuityYear
                                                              AND psc.AnnuityMonth = si.AnnuityMonth
                    WHERE   si.RateVersionID = @RateVersionID;

--SELECT * FROM @PaymentStream
--SELECT @PaymentValue AS GetFromLump

                    SELECT  @PaymentValue = SUM(psc.PaymentValue) / 0.95
                    FROM    @PaymentStream psc;

                    COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;

    END;





GO
/****** Object:  StoredProcedure [qte].[uspGetStlmtBroker]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--DECLARE @MY_ReturnValue AS INT
--DECLARE @MY_StlmtBrokerID INT
--DECLARE @MY_FirstName VARCHAR(50)
--DECLARE @MY_MiddleInitial CHAR(1)
--DECLARE @MY_LastName VARCHAR(50)
--DECLARE @MY_EntityName VARCHAR(100)
--DECLARE @MY_AddrLine1 VARCHAR(100)
--DECLARE @MY_AddrLine2 VARCHAR(100)
--DECLARE @MY_AddrLine3 VARCHAR(100)
--DECLARE @MY_City VARCHAR(100)
--DECLARE @MY_StateCode CHAR(2)
--DECLARE @MY_ZipCode5 CHAR(5)
--DECLARE @MY_PhoneNum CHAR(10)
--EXEC @MY_ReturnValue = qte.uspGetStlmtBroker @StlmtBrokerID=1, 
--      @FirstName	 = @MY_FirstName	 OUTPUT ,
--      @MiddleInitial = @MY_MiddleInitial OUTPUT ,
--      @LastName 	 = @MY_LastName 	 OUTPUT ,
--      @EntityName	 = @MY_EntityName	 OUTPUT ,
--      @AddrLine1 	 = @MY_AddrLine1 	 OUTPUT ,
--      @AddrLine2 	 = @MY_AddrLine2 	 OUTPUT ,
--      @AddrLine3 	 = @MY_AddrLine3 	 OUTPUT ,
--      @City 		 = @MY_City 		 OUTPUT ,
--      @StateCode 	 = @MY_StateCode 	 OUTPUT ,
--      @ZipCode5 	 = @MY_ZipCode5 	 OUTPUT ,
--      @PhoneNum 	 = @MY_PhoneNum 	 OUTPUT 
--SELECT @MY_ReturnValue AS ReturnCode, 
--  @MY_FirstName		AS FirstName	 
--, @MY_MiddleInitial	AS MiddleInitial
--, @MY_LastName		AS LastName 	 
--, @MY_EntityName	AS EntityName	 
--, @MY_AddrLine1		AS AddrLine1 	 
--, @MY_AddrLine2		AS AddrLine2 	 
--, @MY_AddrLine3		AS AddrLine3 	 
--, @MY_City			AS City 		 
--, @MY_StateCode		AS StateCode 	 
--, @MY_ZipCode5		AS ZipCode5 	 
--, @MY_PhoneNum		AS PhoneNum 	 
--============================================================================
CREATE PROCEDURE [qte].[uspGetStlmtBroker]
    (
      @StlmtBrokerID INT ,
      @FirstName VARCHAR(50) OUTPUT ,
      @MiddleInitial CHAR(1) OUTPUT ,
      @LastName VARCHAR(50) OUTPUT ,
      @EntityName VARCHAR(100) OUTPUT ,
      @AddrLine1 VARCHAR(100) OUTPUT ,
      @AddrLine2 VARCHAR(100) OUTPUT ,
      @AddrLine3 VARCHAR(100) OUTPUT ,
      @City VARCHAR(100) OUTPUT ,
      @StateCode CHAR(2) OUTPUT ,
      @ZipCode5 CHAR(5) OUTPUT ,
      @PhoneNum CHAR(10) OUTPUT
    )
AS
    BEGIN

        SET NOCOUNT ON;

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT; 
		
		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;

        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'StlmtBrokerID = ' + CAST(@StlmtBrokerID AS VARCHAR(20)) + 'FirstName = ' + @FirstName + 'MiddleInitial = ' + @MiddleInitial
            + 'LastName = ' + @LastName + 'EntityName = ' + @EntityName + 'AddrLine1 = ' + @AddrLine1 + 'AddrLine2 = ' + @AddrLine2 + 'AddrLine3 = '
            + @AddrLine3 + 'City = ' + @City + 'StateCode = ' + @StateCode + 'ZipCode5 = ' + @ZipCode5 + 'PhoneNum = ' + @PhoneNum; 

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

                    SELECT  @FirstName = ISNULL(FirstName, ''),
                            @MiddleInitial = ISNULL(MiddleInitial, ' ') ,
                            @LastName = ISNULL(LastName, '') ,
                            @EntityName = ISNULL(EntityName, '') ,
                            @AddrLine1 = ISNULL(AddrLine1, '') ,
                            @AddrLine2 = ISNULL(AddrLine2, '') ,
                            @AddrLine3 = ISNULL(AddrLine3, '') ,
                            @City = ISNULL(City, '') ,
                            @StateCode = ISNULL(StateCode, '') ,
                            @ZipCode5 = ISNULL(ZipCode5, '') ,
                            @PhoneNum = ISNULL(PhoneNum, '')
                    FROM    qte.StlmtBroker
                    WHERE   StlmtBrokerID = @StlmtBrokerID;

                    COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;

    END;
GO
/****** Object:  StoredProcedure [qte].[uspSetValuesLifeAndCertain]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--DECLARE @MY_ReturnValue AS INT
--EXEC @MY_ReturnValue = qte.uspSetValuesLifeAndCertain @BenefitQuoteID=1, @UseCertainComponent=1, @UseContingentComponent=1
--SELECT @MY_ReturnValue as ReturnCode
--============================================================================
CREATE PROCEDURE [qte].[uspSetValuesLifeAndCertain]
    (
      @BenefitQuoteID AS INT ,
      @UseCertainComponent AS BIT ,
      @UseContingentComponent AS BIT ,
      @LifeExp AS FLOAT ,
      @FinalPremiumAmt DECIMAL(18, 2) OUTPUT ,
      @FinalBenefitAmt DECIMAL(18, 2) OUTPUT ,
      @FinalPaymentValueAmt FLOAT OUTPUT
    )
AS
    BEGIN

        SET NOCOUNT ON;

        DECLARE @StartRun AS DATETIME2(7);
        SET @StartRun = SYSDATETIME();
        DECLARE @EndRun AS DATETIME2(7);

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT; 
		
        DECLARE @PurchaseDate AS DATE;
        DECLARE @FirstPaymentDate AS DATE;
        DECLARE @PaymentMode AS INT;
        DECLARE @CertainYears AS INT;
        DECLARE @CertainMonths AS INT;
        DECLARE @LastCertainPaymentDate AS DATE;
        DECLARE @LastContingentPaymentDate AS DATE;
        DECLARE @BenefitAmt AS FLOAT;
        DECLARE @PremiumAmt AS FLOAT;
        DECLARE @PaymentValue AS FLOAT;
        DECLARE @PremiumKnown AS BIT;
        DECLARE @ImprovementPct AS DECIMAL(19, 12);
        DECLARE @AnnuitantID AS INT;
        DECLARE @RateVersionID AS INT;
		DECLARE @MinFirstPaymentDate AS DATE

		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;

        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'BenefitQuoteID = ' + CAST(@BenefitQuoteID AS VARCHAR(20));

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

                    SELECT  @PurchaseDate = q.PurchaseDate ,
                            @FirstPaymentDate = bq.FirstPaymentDate ,
                            @PaymentMode = CASE bq.PaymentMode
                                             WHEN 'A' THEN 12
                                             WHEN 'S' THEN 6
                                             WHEN 'Q' THEN 3
                                             WHEN 'M' THEN 1
                                             WHEN 'O' THEN 12
                                             ELSE 12
                                           END ,
                            @CertainYears = bq.CertainYears ,
                            @CertainMonths = bq.CertainMonths ,
                            @BenefitAmt = bq.BenefitAmt ,
                            @PremiumAmt = bq.PremiumAmt ,
                            @ImprovementPct = bq.ImprovementPct / 100. ,
                            @AnnuitantID = bq.PrimaryAnnuitantID ,
                            @RateVersionID = q.RateVersionID
                    FROM    qte.BenefitQuote bq
                            INNER JOIN qte.Quote q ON bq.QuoteID = q.QuoteID
                    WHERE   bq.BenefitQuoteID = @BenefitQuoteID;

					SET @MinFirstPaymentDate = DATEADD(MONTH,1,@PurchaseDate)

                    IF @BenefitAmt > 0
                        SET @PremiumKnown = 0;
                    ELSE
                        SET @PremiumKnown = 1;

                    SET @LastCertainPaymentDate = '1/1/0001';
                    SET @LastContingentPaymentDate = '12/31/9999';
                    IF @UseCertainComponent = 1
                        AND @UseContingentComponent = 1
                        SET @LastCertainPaymentDate = DATEADD(MONTH, ( @CertainYears * 12 ) + @CertainMonths - 1, @FirstPaymentDate);

                    IF @UseCertainComponent = 1
                        AND @UseContingentComponent = 0
                        SET @LastCertainPaymentDate = DATEADD(MONTH, ( @CertainYears * 12 ) - 1, @FirstPaymentDate);

					-- Using the last certain payment date as last 
                    IF @UseCertainComponent = 0
                        AND @UseContingentComponent = 1
                        SET @LastContingentPaymentDate = DATEADD(MONTH, ( @CertainYears * 12 ), @FirstPaymentDate);

                    DELETE  FROM qte.PaymentStream
                    WHERE   BenefitQuoteID = @BenefitQuoteID

                    ;WITH    bs ( Number )
                              AS ( SELECT   0 AS Number
                                   UNION ALL
                                   SELECT   Number + 1
                                   FROM     bs
                                   WHERE    Number < 1440
                                 )
                        INSERT  INTO qte.PaymentStream
                                ( BenefitQuoteID ,
								  CertainAmt ,
                                  ContingentAmt ,
                                  AnnuityYear ,
                                  AnnuityMonth ,
                                  AnnuityAccumMonth ,
                                  AnnuityDate ,
                                  MakePayment
                                )
                                SELECT  @BenefitQuoteID ,
										0.0 ,
                                        0.0 ,
                                        ( ( Number - 1 ) / 12 ) + 1 AS AnnuityYear ,
                                        CASE WHEN Number = 0 THEN 0
                                             ELSE CASE WHEN ( Number % 12 ) = 0 THEN 12
                                                       ELSE ( Number % 12 )
                                                  END
                                        END AS AnnuityMonth ,
                                        Number AS AnnuityAccumMonth ,
                                        DATEADD(MONTH, ( ( ( Number - 1 ) / 12 ) * 12 ) + CASE WHEN Number = 0 THEN 0
                                                                                               ELSE CASE WHEN ( Number % 12 ) = 0 THEN 12
                                                                                                         ELSE ( Number % 12 )
                                                                                                    END
                                                                                          END, @PurchaseDate) AS AnnuityDate ,
										0 AS MakePayment
                                FROM    bs
                        OPTION  ( MAXRECURSION 1440 );

						-- The first payment must be at least a month after the purchase date (@MinFirstPaymentDate)
						-- The desired first payment is within the next annuity month (i.e. if annuity dates are on the 29th of each month, 
						-- then a desired first payment date on the 15th would back up the actual first payment to the 29th of the previous month)
						-- The first payment is never the first month of the contract
						UPDATE  ps
						SET     MakePayment = 1
						FROM    qte.PaymentStream ps
						WHERE   DATEADD(MONTH, 1, ps.AnnuityDate) >= @MinFirstPaymentDate
								AND @FirstPaymentDate <= DATEADD(MONTH, 1, ps.AnnuityDate)
								AND ps.AnnuityAccumMonth <> 0
								AND BenefitQuoteID = @BenefitQuoteID;

						DECLARE @ActualFirstPaymentDate AS DATE;

						SELECT  @ActualFirstPaymentDate = MIN(AnnuityDate)
						FROM    qte.PaymentStream
						WHERE   MakePayment = 1
								AND BenefitQuoteID = @BenefitQuoteID;

                    UPDATE  qte.PaymentStream
                    SET     MakePayment = CASE WHEN ABS(DATEDIFF(MONTH, AnnuityDate, @ActualFirstPaymentDate)) % @PaymentMode = 0 THEN 1
                                               ELSE 0
                                          END
                    WHERE   AnnuityDate > @ActualFirstPaymentDate
                            AND BenefitQuoteID = @BenefitQuoteID;

                    IF @UseCertainComponent = 1
                        BEGIN

                            UPDATE  psc
                            SET     CertainAmt = CASE WHEN @UseCertainComponent = 1
                                                      THEN CASE WHEN psc.MakePayment = 1
                                                                     AND DATEADD(MONTH, ( @CertainYears * 12 ) + @CertainMonths, @ActualFirstPaymentDate) >= psc.AnnuityDate
                                                                     AND @LastCertainPaymentDate >= psc.AnnuityDate
                                                                THEN CASE WHEN psc.AnnuityYear = 1 THEN 1.0
																		  -- Hard-code 1 for premium <-> benefit calculation
                                                                          ELSE 1.0
                                                                               * CAST(POWER(1 + @ImprovementPct,
                                                                                            DATEDIFF(MONTH, @ActualFirstPaymentDate, psc.AnnuityDate) / 12) AS FLOAT)
                                                                     END
                                                                ELSE 0
                                                           END
                                                      ELSE 0
                                                 END ,
                                    ContingentAmt = CASE WHEN @UseContingentComponent = 1
                                                         THEN CASE WHEN psc.MakePayment = 1
                                                                        AND DATEADD(MONTH, ( @CertainYears * 12 ) + @CertainMonths, @ActualFirstPaymentDate) <= psc.AnnuityDate
                                                                        AND @LastCertainPaymentDate < psc.AnnuityDate
                                                                   THEN CASE WHEN psc.AnnuityYear = 1 THEN 1.0
																			 -- Hard-code 1 for premium <-> benefit calculation
                                                                             ELSE 1.0
                                                                                  * CAST(POWER(1 + @ImprovementPct,
                                                                                               DATEDIFF(MONTH, @ActualFirstPaymentDate, psc.AnnuityDate) / 12) AS FLOAT)
                                                                        END
                                                                   ELSE 0
                                                              END
                                                         ELSE 0
                                                    END
                            FROM    qte.PaymentStream psc
                            WHERE psc.BenefitQuoteID = @BenefitQuoteID

                        END;
                    IF @UseCertainComponent = 0
                        BEGIN

                            UPDATE  psc
                            SET     CertainAmt = 0 ,
                                    ContingentAmt = CASE WHEN psc.MakePayment = 1
                                                              AND DATEADD(MONTH, ( @CertainYears * 12 ) + @CertainMonths, @ActualFirstPaymentDate) > psc.AnnuityDate
                                                              AND @LastContingentPaymentDate > psc.AnnuityDate
                                                         THEN CASE WHEN psc.AnnuityYear = 1 THEN 1.0
                                                                   ELSE 1.0
                                                                        * CAST(POWER(1 + @ImprovementPct,
                                                                                     DATEDIFF(MONTH, @ActualFirstPaymentDate, psc.AnnuityDate) / 12) AS FLOAT)
                                                              END
                                                         ELSE 0
                                                    END
                            FROM    qte.PaymentStream psc
                            WHERE psc.BenefitQuoteID = @BenefitQuoteID

                        END;
                    
                    UPDATE  qte.PaymentStream
                    SET     PaymentStreamS = 1
                    WHERE   AnnuityYear = 1
                            AND AnnuityMonth = 0
							AND BenefitQuoteID = @BenefitQuoteID

                    UPDATE  psc
                    SET     PaymentStreamS = CAST(POWER(1. - lem.LifeExpMultipleQx, 1. / 12.) AS FLOAT)
                    FROM    qte.PaymentStream psc
                            INNER JOIN qte.LifeExpMultiple lem ON psc.AnnuityYear = lem.AnnuityYear
                    WHERE   psc.AnnuityYear = 1
                            AND psc.AnnuityMonth = 1
                            AND lem.AnnuitantID = @AnnuitantID
                            AND lem.UseImprovement = CASE WHEN @ImprovementPct > 0 THEN 1
                                                          ELSE 0
                                                     END
							AND psc.BenefitQuoteID = @BenefitQuoteID

;
                    WITH    cte
                              AS ( SELECT   AnnuityYear ,
                                            AnnuityAccumMonth ,
                                            PaymentStreamS
                                   FROM     qte.PaymentStream
								   WHERE BenefitQuoteID = @BenefitQuoteID
                                 ),
                            cte2 ( AnnuityYear, AnnuityAccumMonth, PaymentStreamS )
                              AS ( SELECT   AnnuityYear ,
                                            AnnuityAccumMonth ,
                                            PaymentStreamS
                                   FROM     cte
                                   WHERE    cte.AnnuityAccumMonth = 1
                                   UNION ALL
                                   SELECT   cte.AnnuityYear ,
                                            cte.AnnuityAccumMonth ,
                                            CAST(POWER(1. - lem.LifeExpMultipleQx, 1. / 12.) * cte2.PaymentStreamS AS FLOAT) AS PaymentStreamS
                                   FROM     cte
                                            INNER JOIN cte2 ON cte.AnnuityAccumMonth = cte2.AnnuityAccumMonth + 1
                                            INNER JOIN qte.LifeExpMultiple lem ON cte.AnnuityYear = lem.AnnuityYear
                                 )

					UPDATE  p
					SET     p.PaymentStreamS = cte2.PaymentStreamS
					FROM    qte.PaymentStream p
							INNER JOIN cte2 ON cte2.AnnuityAccumMonth = p.AnnuityAccumMonth
					WHERE   p.AnnuityAccumMonth > 1
							AND p.BenefitQuoteID = @BenefitQuoteID
					OPTION  ( MAXRECURSION 1441 );

                    UPDATE  psc
                    SET     psc.PaymentValue = CASE WHEN @UseCertainComponent = 1 THEN ( psc.CertainAmt * si.SpotInterestVx )
                                                    ELSE 0
                                               END + CASE WHEN @UseContingentComponent = 1 THEN ( psc.ContingentAmt * psc.PaymentStreamS * si.SpotInterestVx )
                                                          ELSE 0
                                                     END ,
                            psc.ExpectedT = CASE WHEN @UseCertainComponent = 1 THEN ( psc.CertainAmt )
                                                 ELSE 0
                                            END + CASE WHEN @UseContingentComponent = 1 THEN ( psc.ContingentAmt * psc.PaymentStreamS )
                                                       ELSE 0
                                                  END ,
                            psc.ExpectedN = CASE WHEN psc.AnnuityYear <= CAST(@LifeExp AS INT) THEN psc.CertainAmt + psc.ContingentAmt
                                                 ELSE 0
                                            END
                    FROM    qte.PaymentStream psc
                            INNER JOIN qte.SpotInterest si ON psc.AnnuityYear = si.AnnuityYear
                                                              AND psc.AnnuityMonth = si.AnnuityMonth
                    WHERE   si.RateVersionID = @RateVersionID
					AND psc.BenefitQuoteID = @BenefitQuoteID

                    SELECT  @PaymentValue = SUM(psc.PaymentValue) 
                    FROM    qte.PaymentStream psc
					WHERE psc.BenefitQuoteID = @BenefitQuoteID;

                    IF @PremiumKnown = 1
                        BEGIN
                            SET @BenefitAmt = CAST(@PremiumAmt * 0.95 / @PaymentValue AS DECIMAL(18, 2));
                        END;
                    ELSE
                        BEGIN
                            SET @PremiumAmt = CAST(@BenefitAmt * @PaymentValue / 0.95 AS DECIMAL(18, 2));
                        END;

                    UPDATE  qte.BenefitQuote
                    SET     PremiumAmt = @PremiumAmt ,
                            BenefitAmt = @BenefitAmt 
                    WHERE   BenefitQuoteID = @BenefitQuoteID;

                    SET @FinalPremiumAmt = @PremiumAmt;
                    SET @FinalBenefitAmt = @BenefitAmt;
                    SET @FinalPaymentValueAmt = CAST(@PaymentValue AS FLOAT);

--SELECT * FROM qte.PaymentStream

                    COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

                    SET @EndRun = SYSDATETIME();
                    INSERT  INTO qte.ProcedureLog
                            ( ProcedureName ,
                              RunStart ,
                              RunEnd
                            )
                    VALUES  ( OBJECT_NAME(@@PROCID) ,
                              @StartRun ,
                              @EndRun
                            );

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;

    END;






GO
/****** Object:  StoredProcedure [qte].[uspSetValuesLumpSum]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


--DECLARE @out_ReturnValue AS INT
--EXEC @out_ReturnValue = qte.uspSetValuesLumpSum @BenefitQuoteID=1
--SELECT @out_ReturnValue as ReturnCode
--============================================================================
CREATE PROCEDURE [qte].[uspSetValuesLumpSum]
    (
      @BenefitQuoteID AS INT ,
      @LifeExp AS FLOAT ,
      @FinalPremiumAmt DECIMAL(18, 2) OUTPUT ,
      @FinalBenefitAmt DECIMAL(18, 2) OUTPUT ,
      @FinalPaymentValueAmt FLOAT OUTPUT
    )
AS
    BEGIN

        SET NOCOUNT ON;

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT; 
		
        DECLARE @RateVersionID AS INT;
        DECLARE @AnnuitantID AS INT;
        DECLARE @PurchaseDate AS DATE;
        DECLARE @BenefitAmt AS FLOAT;
        DECLARE @PremiumAmt AS FLOAT;
        DECLARE @PaymentValue AS FLOAT;
        DECLARE @FirstPaymentDate AS DATE;
        DECLARE @PremiumKnown AS BIT;
        DECLARE @ImprovementPct AS DECIMAL(19, 12);
        DECLARE @TotalExpected1 DECIMAL(19, 2); 
        DECLARE @TotalExpected2 DECIMAL(19, 2); 
        DECLARE @Guaranteed DECIMAL(19, 2); 
		DECLARE @MinFirstPaymentDate AS DATE

		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;

        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'BenefitQuoteID = ' + CAST(@BenefitQuoteID AS VARCHAR(20));

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

                    SELECT  @PurchaseDate = q.PurchaseDate ,
                            @FirstPaymentDate = bq.FirstPaymentDate ,
                            @BenefitAmt = bq.BenefitAmt ,
                            @PremiumAmt = bq.PremiumAmt ,
                            @AnnuitantID = bq.PrimaryAnnuitantID ,
                            @ImprovementPct = bq.ImprovementPct / 100. ,
                            @RateVersionID = q.RateVersionID
                    FROM    qte.BenefitQuote bq
                            INNER JOIN qte.Quote q ON bq.QuoteID = q.QuoteID
                    WHERE   bq.BenefitQuoteID = @BenefitQuoteID;

					SET @MinFirstPaymentDate = DATEADD(MONTH,1,@PurchaseDate)

                    IF @BenefitAmt > 0
                        SET @PremiumKnown = 0;
                    ELSE
                        SET @PremiumKnown = 1;

                    DELETE  FROM qte.PaymentStream
                    WHERE   BenefitQuoteID = @BenefitQuoteID

                    ;WITH    bs ( Number )
                              AS ( SELECT   0 AS Number
                                   UNION ALL
                                   SELECT   Number + 1
                                   FROM     bs
                                   WHERE    Number < 1440
                                 )
                        INSERT  INTO qte.PaymentStream
                                ( BenefitQuoteID ,
								  CertainAmt ,
                                  ContingentAmt ,
                                  AnnuityYear ,
                                  AnnuityMonth ,
                                  AnnuityAccumMonth ,
                                  AnnuityDate ,
                                  MakePayment
                                )
                                SELECT  @BenefitQuoteID ,
										0.0 ,
                                        0.0 ,
                                        ( ( Number - 1 ) / 12 ) + 1 AS AnnuityYear ,
                                        CASE WHEN Number = 0 THEN 0
                                             ELSE CASE WHEN ( Number % 12 ) = 0 THEN 12
                                                       ELSE ( Number % 12 )
                                                  END
                                        END AS AnnuityMonth ,
                                        Number AS AnnuityAccumMonth ,
                                        DATEADD(MONTH, ( ( ( Number - 1 ) / 12 ) * 12 ) + CASE WHEN Number = 0 THEN 0
                                                                                               ELSE CASE WHEN ( Number % 12 ) = 0 THEN 12
                                                                                                         ELSE ( Number % 12 )
                                                                                                    END
                                                                                          END, @PurchaseDate) AS AnnuityDate ,
										0 AS MakePayment
                                FROM    bs
                        OPTION  ( MAXRECURSION 1440 );

--UPDATE qte.PaymentStream
--SET MakePayment = 1
--WHERE AnnuityDate = @FirstPaymentDate

						-- The first payment must be at least a month after the purchase date (@MinFirstPaymentDate)
						-- The desired first payment is within the next annuity month (i.e. if annuity dates are on the 29th of each month, 
						-- then a desired first payment date on the 15th would back up the actual first payment to the 29th of the previous month)
						-- The first payment is never the first month of the contract
						UPDATE  ps
						SET     MakePayment = 1
						FROM    qte.PaymentStream ps
						WHERE   DATEADD(MONTH, 1, ps.AnnuityDate) >= @MinFirstPaymentDate
								AND @FirstPaymentDate >= ps.AnnuityDate
								AND @FirstPaymentDate < DATEADD(MONTH, 1, ps.AnnuityDate)
								AND ps.AnnuityAccumMonth <> 0
								AND BenefitQuoteID = @BenefitQuoteID;

						DECLARE @ActualFirstPaymentDate AS DATE;

						SELECT  @ActualFirstPaymentDate = MIN(AnnuityDate)
						FROM    qte.PaymentStream
						WHERE   MakePayment = 1
								AND BenefitQuoteID = @BenefitQuoteID;

						UPDATE qte.PaymentStream
						SET MakePayment = 0
						FROM    qte.PaymentStream
						WHERE   MakePayment = 1
						AND AnnuityDate > @ActualFirstPaymentDate
								AND BenefitQuoteID = @BenefitQuoteID;



                    --SELECT  @FirstPaymentDate = AnnuityDate
                    --FROM    qte.PaymentStream
                    --WHERE   MakePayment = 1
                    --        AND BenefitQuoteID = @BenefitQuoteID;

                    UPDATE  qte.PaymentStream
                    --SET     CertainAmt = CASE WHEN @BenefitAmt > 0 THEN @BenefitAmt ELSE 1.0 END
                    SET     CertainAmt = 1.0
                    WHERE   MakePayment = 1
                            AND BenefitQuoteID = @BenefitQuoteID;

                    UPDATE  qte.PaymentStream
                    SET     PaymentStreamS = 1
                    WHERE   AnnuityYear = 1
                            AND AnnuityMonth = 0
                            AND BenefitQuoteID = @BenefitQuoteID;

                    UPDATE  psc
                    SET     PaymentStreamS = CAST(POWER(1. - lem.LifeExpMultipleQx, 1. / 12.) AS FLOAT)
                    FROM    qte.PaymentStream psc
                            INNER JOIN qte.LifeExpMultiple lem ON psc.AnnuityYear = lem.AnnuityYear
                    WHERE   psc.AnnuityYear = 1
                            AND psc.AnnuityMonth = 1
                            AND lem.AnnuitantID = @AnnuitantID
                            AND lem.UseImprovement = CASE WHEN @ImprovementPct > 0 THEN 1
                                                          ELSE 0
                                                     END
                            AND BenefitQuoteID = @BenefitQuoteID;

                    DECLARE @i INT;
                    SET @i = 2;
                    WHILE @i <= 1441
                        BEGIN

                            UPDATE  psc
                            SET     PaymentStreamS = CAST(POWER(1. - lem.LifeExpMultipleQx, 1. / 12.) * psp.PaymentStreamS AS FLOAT)
                            FROM    qte.PaymentStream psc
                                    INNER JOIN qte.LifeExpMultiple lem ON psc.AnnuityYear = lem.AnnuityYear
                                    LEFT JOIN qte.PaymentStream psp ON psp.AnnuityAccumMonth = psc.AnnuityAccumMonth - 1
                            WHERE   psc.AnnuityAccumMonth = @i
                                    AND lem.AnnuitantID = @AnnuitantID
                                    AND lem.UseImprovement = CASE WHEN @ImprovementPct > 0 THEN 1
                                                                  ELSE 0
                                                             END
									AND psc.BenefitQuoteID = @BenefitQuoteID
									AND psp.BenefitQuoteID = @BenefitQuoteID;

                            SET @i = @i + 1;
                        END;

                    UPDATE  psc
                    SET     psc.PaymentValue = ( psc.CertainAmt * si.SpotInterestVx ) , --+ ( psc.ContingentAmt * psc.PaymentStreamS * si.SpotInterestVx )
                            psc.ExpectedT = psc.CertainAmt ,
                            psc.ExpectedN = CASE WHEN psc.AnnuityYear <= CAST(@LifeExp AS INT) THEN psc.CertainAmt 
                                                 ELSE 0
                                            END

                    FROM    qte.PaymentStream psc
                            INNER JOIN qte.SpotInterest si ON psc.AnnuityYear = si.AnnuityYear
                                                              AND psc.AnnuityMonth = si.AnnuityMonth
                    WHERE   si.RateVersionID = @RateVersionID
                            AND psc.MakePayment = 1
							AND psc.BenefitQuoteID = @BenefitQuoteID

--SELECT  * FROM    qte.PaymentStream;

                    SELECT  @PaymentValue = SUM(psc.PaymentValue) 
                    FROM    qte.PaymentStream psc
                    WHERE   psc.BenefitQuoteID = @BenefitQuoteID;

                    IF @PremiumKnown = 1
                        BEGIN
                            SET @BenefitAmt = CAST(@PremiumAmt * 0.95 / @PaymentValue AS DECIMAL(18, 2));
                        END;
                    ELSE
                        BEGIN
                            SET @PremiumAmt = CAST(@BenefitAmt * @PaymentValue / 0.95 AS DECIMAL(18, 2));
							--SET @PremiumAmt = CAST(@PaymentValue / 0.95 AS DECIMAL(18, 2))
                        END;
                    
                    UPDATE  qte.BenefitQuote
                    SET     PremiumAmt = @PremiumAmt ,
                            BenefitAmt = @BenefitAmt 
                    WHERE   BenefitQuoteID = @BenefitQuoteID;

                    SET @FinalPremiumAmt = CAST(@PremiumAmt AS DECIMAL(19, 2));
                    SET @FinalBenefitAmt = CAST(@BenefitAmt AS DECIMAL(19, 2));
                    SET @FinalPaymentValueAmt = CAST(@PaymentValue AS DECIMAL(19, 2));

--SELECT @FinalPremiumAmt, @FinalBenefitAmt, @PremiumKnown, @BenefitAmt, @PaymentValue
--SELECT * FROM qte.PaymentStream

                    COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;

    END;





GO
/****** Object:  StoredProcedure [qte].[uspUpsertAnnuitant]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--EXEC qte.uspUpsertAnnuitant @QuoteID=1, @AnnuitantID=NULL, @DOB='1/1/1980', @FirstName='John - 1', @LastName='Doe', @RatedAge=40, @Gender='M'
--============================================================================
CREATE PROCEDURE [qte].[uspUpsertAnnuitant]
    (
      @QuoteID INT ,
      @AnnuitantID INT = NULL ,
      @DOB DATE ,
      @FirstName VARCHAR(50) ,
      @LastName VARCHAR(50) ,
      @RatedAge INT ,
      @Gender CHAR(1)
    )
AS
    BEGIN

        SET NOCOUNT ON;

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT ,
            @TransactionDate AS DATETIME;

		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;
        SET @TransactionDate = GETDATE();
					
        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'QuoteID = ' + CAST(@QuoteID AS VARCHAR(20)) 
			+ ' AnnuitantID = ' + CAST(ISNULL(@AnnuitantID, 0) AS VARCHAR(20)) 
			+ ' DOB = ' + CAST(@DOB AS VARCHAR(20)) 
			+ ' FirstName = ' + @FirstName
            + ' LastName = ' + @LastName + ' RatedAge = ' + CAST(@RatedAge AS VARCHAR(20)) 
			+ ' Gender = ' + @Gender;

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

					IF @AnnuitantID = 0 
						SET @AnnuitantID = NULL

                    IF EXISTS ( SELECT TOP 1
                                        *
                                FROM    qte.Annuitant
                                WHERE   AnnuitantID = ISNULL(@AnnuitantID, -1)
                                        AND QuoteID = @QuoteID )
                        BEGIN

                            UPDATE  qte.Annuitant
                            SET     DOB = @DOB ,
                                    FirstName = @FirstName ,
                                    LastName = @LastName ,
                                    RatedAge = @RatedAge ,
                                    Gender = @Gender
                            WHERE   AnnuitantID = @AnnuitantID
                                    AND QuoteID = @QuoteID;

                        END;
                    ELSE
                        BEGIN

                            INSERT  INTO qte.Annuitant
                                    ( QuoteID ,
                                      FirstName ,
                                      LastName ,
                                      DOB ,
                                      RatedAge ,
                                      Gender
							        )
                            VALUES  ( @QuoteID ,
                                      @FirstName ,
                                      @LastName ,
                                      @DOB ,
                                      @RatedAge ,
                                      @Gender 
							        );

                        END;
	
                    IF @@TRANCOUNT > 0
                        COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;
    END;


GO
/****** Object:  StoredProcedure [qte].[uspUpsertBenefitQuote]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


--DECLARE @MY_ReturnValue AS INT
--DECLARE @MY_FinalPremiumAmt AS decimal(18,2)
--DECLARE @MY_FinalPremiumAmt AS decimal(18,2)
--EXEC qte.uspUpsertBenefitQuote @BenefitQuoteID=0, @QuoteID=1, @BenefitID=1, @PrimaryAnnuitantID=1, @JointAnnuitantID=1, @PaymentMode='M', @BenefitAmt=3500.00, @PremiumAmt=0.0, @FirstPaymentDate='10/15/2017', @CertainYears=30, @CertainMonths=0, @ImprovementPct=0.0, @EndDate='1/1/0001', @FinalPremiumAmt=@MY_FinalPremiumAmt OUTPUT, @FinalBenefitAmt=@MY_BenefitPremiumAmt OUTPUT
--SELECT @MY_FinalPremiumAmt AS FinalPremiumAmt
--============================================================================
CREATE PROCEDURE [qte].[uspUpsertBenefitQuote]
    (
      @BenefitQuoteID INT ,
      @QuoteID INT ,
      @BenefitID INT ,
      @PrimaryAnnuitantID INT ,
      @JointAnnuitantID INT ,
      @PaymentMode CHAR(1) ,
      @BenefitAmt DECIMAL(18, 2) ,
      @PremiumAmt DECIMAL(18, 2) ,
      @FirstPaymentDate DATE ,
      @CertainYears INT ,
      @CertainMonths INT ,
      @ImprovementPct DECIMAL(5, 2) ,
      @EndDate DATE ,
	  @Persist BIT ,
      @FinalPremiumAmt DECIMAL(18, 2) OUTPUT ,
      @FinalBenefitAmt DECIMAL(18, 2) OUTPUT ,
      @FinalPaymentValueAmt FLOAT OUTPUT
    )
AS
    BEGIN

        SET NOCOUNT ON;

		DECLARE @StartRun AS DATETIME2(7);
		SET @StartRun = SYSDATETIME();
		DECLARE @EndRun AS DATETIME2(7);

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT ,
            @TransactionDate AS DATETIME;
        DECLARE @out_BenefitAmt AS DECIMAL(19, 2);
        DECLARE @out_PremiumAmt AS DECIMAL(19, 2);
        DECLARE @out_PaymentValueAmt AS FLOAT

		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;
        SET @TransactionDate = GETDATE();
					
        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'BenefitQuoteID = ' + CAST(@BenefitQuoteID AS VARCHAR(20)) 
			+ ' QuoteID = ' + CAST(@QuoteID AS VARCHAR(20)) 
			+ ' BenefitID = ' + CAST(@BenefitID AS VARCHAR(20)) 
			+ ' PrimaryAnnuitantID = ' + CAST(@PrimaryAnnuitantID AS VARCHAR(20)) 
			+ ' JointAnnuitantID = ' + CAST(@JointAnnuitantID AS VARCHAR(20)) 
			+ ' PaymentMode = ' + @PaymentMode
            + ' BenefitAmt = ' + CAST(@BenefitAmt AS VARCHAR(20)) 
			+ ' PremiumAmt = ' + CAST(@PremiumAmt AS VARCHAR(20)) 
			+ ' FirstPaymentDate = ' + CAST(@FirstPaymentDate AS VARCHAR(20)) 
			+ ' CertainYears = ' + CAST(@CertainYears AS VARCHAR(20)) 
			+ ' CertainMonths = ' + CAST(@CertainMonths AS VARCHAR(20)) 
			+ ' ImprovementPct = ' + CAST(@ImprovementPct AS VARCHAR(20)) 
			+ ' EndDate = ' + CAST(@EndDate AS VARCHAR(20))
			+ ' Persist = ' + CAST(@Persist AS VARCHAR(20));

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

                    IF EXISTS ( SELECT TOP 1
                                        *
                                FROM    qte.BenefitQuote
                                WHERE   BenefitQuoteID = ISNULL(@BenefitQuoteID, -1) )
                        BEGIN

                            UPDATE  qte.BenefitQuote
                            SET     BenefitID = @BenefitID ,
                                    PrimaryAnnuitantID = @PrimaryAnnuitantID ,
                                    JointAnnuitantID = @JointAnnuitantID ,
                                    PaymentMode = @PaymentMode ,
                                    BenefitAmt = @BenefitAmt ,
                                    PremiumAmt = @PremiumAmt ,
                                    FirstPaymentDate = @FirstPaymentDate ,
                                    CertainYears = @CertainYears ,
                                    CertainMonths = @CertainMonths ,
                                    ImprovementPct = @ImprovementPct ,
                                    EndDate = @EndDate
                            WHERE   BenefitQuoteID = @BenefitQuoteID;

                        END;
                    ELSE
                        BEGIN

                            INSERT  INTO qte.BenefitQuote
                                    ( QuoteID ,
                                      BenefitID ,
                                      PrimaryAnnuitantID ,
                                      JointAnnuitantID ,
                                      PaymentMode ,
                                      BenefitAmt ,
                                      PremiumAmt ,
                                      FirstPaymentDate ,
                                      CertainYears ,
                                      CertainMonths ,
                                      ImprovementPct ,
                                      EndDate
                                    )
                            VALUES  ( @QuoteID ,
                                      @BenefitID ,
                                      @PrimaryAnnuitantID ,
                                      @JointAnnuitantID ,
                                      @PaymentMode ,
                                      @BenefitAmt ,
                                      @PremiumAmt ,
                                      @FirstPaymentDate ,
                                      @CertainYears ,
                                      @CertainMonths ,
                                      @ImprovementPct ,
                                      @EndDate
							        );

                            SET @BenefitQuoteID = @@IDENTITY;

                        END;
	
                    DECLARE @ThisIssueAge AS INT;
                    DECLARE @ThisRatedAge AS INT;
                    DECLARE @ThisRateVersionID AS INT;
                    DECLARE @ThisGender AS CHAR(1);
                    DECLARE @ThisUseImprovement AS BIT;

                    SELECT  @ThisIssueAge = ( CONVERT(INT, CONVERT(CHAR(8), GETDATE(), 112)) - CONVERT(CHAR(8), DOB, 112) ) / 10000 ,
                            @ThisRatedAge = RatedAge ,
                            @ThisGender = Gender
                    FROM    qte.Annuitant
                    WHERE   AnnuitantID = @PrimaryAnnuitantID;

                    SELECT  @ThisRateVersionID = RateVersionID
                    FROM    qte.Quote
                    WHERE   QuoteID = @QuoteID;

                    SET @ThisUseImprovement = CASE WHEN @ImprovementPct > 0 THEN 1
                                                   ELSE 0
                                              END;

-- Extra Death = 0
-- Multiplier = 1
					--IF @ThisRatedAge <> @ThisIssueAge
					--	BEGIN

							--   Step one - Calculate Rated Age Life Expectancy
							DECLARE @out_LifeExpRatedAgeFactor AS FLOAT; 
							DECLARE @out_ReturnValue AS INT;
							EXEC @out_ReturnValue = qte.uspGetLifeExpRatedAge @RatedAge = @ThisRatedAge, @IssueAge = @ThisIssueAge, @Gender = @ThisGender,
								@RateVersionID = @ThisRateVersionID, @UseImprovement = @ThisUseImprovement
								, @LifeExpRatedAgeFactor = @out_LifeExpRatedAgeFactor OUTPUT;

							-- Step two - Calc Extra Deaths at actual age
							DECLARE @out_LifeExpExtraDeathFactor AS FLOAT; 
							DECLARE @out_ExtraDeathRateOut AS FLOAT; 
							EXEC @out_ReturnValue = qte.uspGetLifeExpExtraDeath @RatedAgeLifeExp = @out_LifeExpRatedAgeFactor, @RatedAge = @ThisRatedAge,
								@IssueAge = @ThisIssueAge, @Gender = @ThisGender, @RateVersionID = @ThisRateVersionID, @UseImprovement = @ThisUseImprovement,
								@LifeExpExtraDeathFactor = @out_LifeExpExtraDeathFactor OUTPUT, @ExtraDeathRateOut = @out_ExtraDeathRateOut OUTPUT;

					--	END
					--ELSE
					--	BEGIN

							--SET @out_LifeExpRatedAgeFactor = 1
							--SET @out_ExtraDeathRateOut = 0

--						END

					-- Step three - Calc Multiple using one-half extra deaths
                    EXEC @out_ReturnValue = qte.uspGetLifeExpMultiple @RatedAgeLifeExp = @out_LifeExpRatedAgeFactor, @ExtraDeathRate = @out_ExtraDeathRateOut,
                        @RatedAge = @ThisRatedAge, @IssueAge = @ThisIssueAge, @Gender = @ThisGender, @AnnuitantID = @PrimaryAnnuitantID,
                        @UseImprovement = @ThisUseImprovement, @RateVersionID = @ThisRateVersionID;

--SELECT @out_LifeExpRatedAgeFactor, @out_ExtraDeathRateOut


                    DECLARE @ReturnValue AS INT;
                    DECLARE @out_PaymentValue AS DECIMAL(19, 2);

                    DECLARE @BenefitDescr AS VARCHAR(50);
                    SELECT  @BenefitDescr = BenefitDescr
                    FROM    qte.Benefit
                    WHERE   BenefitID = @BenefitID;

                    IF @BenefitDescr = 'Life'
                        BEGIN

                            EXEC @ReturnValue = qte.uspSetValuesLifeAndCertain @BenefitQuoteID = @BenefitQuoteID
								, @UseCertainComponent = 1
								, @UseContingentComponent = 1
								, @LifeExp = @out_LifeExpRatedAgeFactor
								, @FinalPremiumAmt = @out_PremiumAmt OUTPUT
								, @FinalBenefitAmt = @out_BenefitAmt OUTPUT
								, @FinalPaymentValueAmt = @out_PaymentValueAmt OUTPUT;

                            SET @FinalPremiumAmt = @out_PremiumAmt;
                            SET @FinalBenefitAmt = @out_BenefitAmt;
                            SET @FinalPaymentValueAmt = @out_PaymentValueAmt;

                        END;
                    IF @BenefitDescr = 'Period Certain'
                        BEGIN

                            EXEC @ReturnValue = qte.uspSetValuesLifeAndCertain @BenefitQuoteID = @BenefitQuoteID
								, @UseCertainComponent = 1
								, @UseContingentComponent = 0
								, @LifeExp = @out_LifeExpRatedAgeFactor
								, @FinalPremiumAmt = @out_PremiumAmt OUTPUT
								, @FinalBenefitAmt = @out_BenefitAmt OUTPUT
								, @FinalPaymentValueAmt = @out_PaymentValueAmt OUTPUT;

                            SET @FinalPremiumAmt = @out_PremiumAmt;
                            SET @FinalBenefitAmt = @out_BenefitAmt;
                            SET @FinalPaymentValueAmt = @out_PaymentValueAmt;

                        END;
                    IF @BenefitDescr = 'Temporary Life'
                        BEGIN

                            EXEC @ReturnValue = qte.uspSetValuesLifeAndCertain @BenefitQuoteID = @BenefitQuoteID
								, @UseCertainComponent = 0
								, @UseContingentComponent = 1
								, @LifeExp = @out_LifeExpRatedAgeFactor
								, @FinalPremiumAmt = @out_PremiumAmt OUTPUT
								, @FinalBenefitAmt = @out_BenefitAmt OUTPUT
								, @FinalPaymentValueAmt = @out_PaymentValueAmt OUTPUT;

                            SET @FinalPremiumAmt = @out_PremiumAmt;
                            SET @FinalBenefitAmt = @out_BenefitAmt;
                            SET @FinalPaymentValueAmt = @out_PaymentValueAmt;

                        END;
                    IF @BenefitDescr = 'Lump Sum'
                        BEGIN

                            EXEC @ReturnValue = qte.uspSetValuesLumpSum @BenefitQuoteID = @BenefitQuoteID
								, @LifeExp = @out_LifeExpRatedAgeFactor
								, @FinalPremiumAmt = @out_PremiumAmt OUTPUT
								, @FinalBenefitAmt = @out_BenefitAmt OUTPUT
								, @FinalPaymentValueAmt = @out_PaymentValueAmt OUTPUT;

                            SET @FinalPremiumAmt = @out_PremiumAmt;
                            SET @FinalBenefitAmt = @out_BenefitAmt;
							SET @FinalPaymentValueAmt = @out_PaymentValueAmt;

                        END;

					IF @Persist = 0
						BEGIN

							DELETE  qte.PaymentStream
							WHERE   BenefitQuoteID = @BenefitQuoteID;

							DELETE  qte.BenefitQuote
							WHERE   BenefitQuoteID = @BenefitQuoteID;

						END
                    
                    IF @@TRANCOUNT > 0
                        COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

					SET @EndRun = SYSDATETIME();
					INSERT  INTO qte.ProcedureLog
							( ProcedureName ,
							  RunStart ,
							  RunEnd
							)
					VALUES  ( OBJECT_NAME(@@PROCID) ,
							  @StartRun ,
							  @EndRun
							);

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;
    END;



GO
/****** Object:  StoredProcedure [qte].[uspUpsertBroker]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--EXEC qte.uspUpsertBroker @StlmtBrokerID=0, @FirstName='Melissa', @MiddleInitial=NULL, @LastName='Parsons', @EntityName=NULL, @AddrLine1='996 Penn Street', @AddrLine2=NULL, @AddrLine3=NULL, @City='Stafford', @StateCode='VA', @ZipCode5='22554', @PhoneNum='8001234567'
--============================================================================
CREATE PROCEDURE [qte].[uspUpsertBroker]
    (
      @StlmtBrokerID INT ,
      @FirstName VARCHAR(50) = NULL ,
      @MiddleInitial CHAR(1) = NULL ,
      @LastName VARCHAR(50) = NULL ,
      @EntityName VARCHAR(100) = NULL ,
      @AddrLine1 VARCHAR(100) ,
      @AddrLine2 VARCHAR(100) = NULL ,
      @AddrLine3 VARCHAR(100) = NULL ,
      @City VARCHAR(100) ,
      @StateCode CHAR(2) ,
      @ZipCode5 CHAR(5) ,
      @PhoneNum CHAR(10)
    )
AS
    BEGIN

        SET NOCOUNT ON;

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT ,
            @TransactionDate AS DATETIME;

		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;
        SET @TransactionDate = GETDATE();
					
        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'StlmtBrokerID = ' + CAST(@StlmtBrokerID AS VARCHAR(10)) + ' FirstName = ' + ISNULL(@FirstName, '') + ' MiddleInitial = '
            + ISNULL(@MiddleInitial, '') + ' LastName = ' + ISNULL(@LastName, '') + ' EntityName = ' + ISNULL(@EntityName, '') + ' AddrLine1 = ' + @AddrLine1
            + ' AddrLine2 = ' + ISNULL(@AddrLine2, '') + ' AddrLine3 = ' + ISNULL(@AddrLine3, '') + ' City = ' + @City + ' StateCode = ' + @StateCode
            + ' ZipCode5 = ' + @ZipCode5 + ' PhoneNum = ' + @PhoneNum;

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

                    IF @StlmtBrokerID = 0
                        SET @StlmtBrokerID = NULL;

                    IF EXISTS ( SELECT TOP 1
                                        *
                                FROM    qte.StlmtBroker
                                WHERE   StlmtBrokerID = ISNULL(@StlmtBrokerID, -1) )
                        BEGIN

                            UPDATE  qte.StlmtBroker
                            SET     FirstName = @FirstName ,
                                    MiddleInitial = @MiddleInitial ,
                                    LastName = @LastName ,
                                    EntityName = @EntityName ,
                                    AddrLine1 = @AddrLine1 ,
                                    AddrLine2 = @AddrLine2 ,
                                    AddrLine3 = @AddrLine3 ,
                                    City = @City ,
                                    StateCode = @StateCode ,
                                    ZipCode5 = @ZipCode5 ,
                                    PhoneNum = @PhoneNum
                            WHERE   StlmtBrokerID = @StlmtBrokerID;

                        END;
                    ELSE
                        BEGIN

                            INSERT  INTO qte.StlmtBroker
                                    ( FirstName ,
                                      MiddleInitial ,
                                      LastName ,
                                      EntityName ,
                                      AddrLine1 ,
                                      AddrLine2 ,
                                      AddrLine3 ,
                                      City ,
                                      StateCode ,
                                      ZipCode5 ,
                                      PhoneNum
                                    )
                            VALUES  ( @FirstName ,
                                      @MiddleInitial ,
                                      @LastName ,
                                      @EntityName ,
                                      @AddrLine1 ,
                                      @AddrLine2 ,
                                      @AddrLine3 ,
                                      @City ,
                                      @StateCode ,
                                      @ZipCode5 ,
                                      @PhoneNum 
                                    );
                        END;
	
                    IF @@TRANCOUNT > 0
                        COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;
    END;
GO
/****** Object:  StoredProcedure [qte].[uspUpsertQuote]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


--DECLARE @MY_ReturnValue AS INT
--DECLARE @MY_NewQuoteID AS INT
--EXEC qte.uspUpsertQuote @QuoteID=1, @StlmtBrokerID=1, @RateVersionID=1, @PurchaseDate='10/15/2017', @BudgetAmt=100000.00, @NewQuoteID=@MY_NewQuoteID OUTPUT
--============================================================================
CREATE PROCEDURE [qte].[uspUpsertQuote]
    (
      @QuoteID INT ,
      @StlmtBrokerID INT ,
      @RateVersionID INT ,
      @PurchaseDate DATE ,
      @BudgetAmt DECIMAL(18, 2) ,
      @NewQuoteID AS INT OUTPUT 
    )
AS
    BEGIN

        SET NOCOUNT ON;

        DECLARE @Tries AS SMALLINT ,
            @SqlReturnSts AS INT ,
            @TransactionDate AS DATETIME2(7);

		-- Retry 3 times for deadlocks
        SET @Tries = 3;
        SET @SqlReturnSts = 0;
        SET @TransactionDate = SYSDATETIME();
					
        DECLARE @procParametersTmp AS NVARCHAR(4000);
        SET @procParametersTmp = 'QuoteID = ' + CAST(@QuoteID AS VARCHAR(20)) + ' StlmtBrokerID = ' + CAST(ISNULL(@StlmtBrokerID, 0) AS VARCHAR(20))
            + ' RateVersionID = ' + CAST(@RateVersionID AS VARCHAR(20)) + ' PurchaseDate = ' + CAST(@PurchaseDate AS VARCHAR(20)) + ' BudgetAmt = '
            + CAST(@BudgetAmt AS VARCHAR(20));

        WHILE @Tries > 0
            AND @SqlReturnSts = 0
            BEGIN

                BEGIN TRY

                    BEGIN TRANSACTION;

                    IF @QuoteID = 0
                        SET @QuoteID = NULL;

                    IF EXISTS ( SELECT TOP 1
                                        *
                                FROM    qte.Quote
                                WHERE   QuoteID = ISNULL(@QuoteID, -1)
                                        AND QuoteID = @QuoteID )
                        BEGIN

                            UPDATE  qte.Quote
                            SET     LastModified = @TransactionDate ,
                                    StlmtBrokerID = @StlmtBrokerID ,
                                    PurchaseDate = @PurchaseDate ,
                                    BudgetAmt = @BudgetAmt
                            WHERE   QuoteID = @QuoteID;

                            SET @NewQuoteID = 0;

                        END;
                    ELSE
                        BEGIN

                            INSERT  INTO qte.Quote
                                    ( QuoteDescr ,
                                      RateVersionID ,
                                      StlmtBrokerID ,
                                      PurchaseDate ,
                                      BudgetAmt
                                    )
                                    SELECT  CONVERT(VARCHAR(20), @TransactionDate, 110) + ' ' + CONVERT(VARCHAR(20), @TransactionDate, 108) ,
                                            @RateVersionID ,
                                            @StlmtBrokerID ,
                                            @PurchaseDate ,
                                            @BudgetAmt;

                            SET @NewQuoteID = @@IDENTITY;

                        END;
	
                    IF @@TRANCOUNT > 0
                        COMMIT TRANSACTION;

                    SET @SqlReturnSts = 0;

					-- break out of the loop if successful 
                    BREAK;
			
                END TRY
                BEGIN CATCH

					-- We want to retry if in a deadlock
                    IF ( ( ERROR_NUMBER() = 1205 )
                         AND ( @Tries > 0 )
                       )
                        BEGIN
                            SET @Tries = @Tries - 1;

                            IF @Tries = 0
                                SET @SqlReturnSts = -1;

                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;
							-- go back to the top of the loop
                            CONTINUE;
                        END;
                    ELSE
                        BEGIN
							-- if not a deadlock then bail out
                            SET @Tries = -1;
                            IF @@TRANCOUNT > 0
                                BEGIN
                                    ROLLBACK TRANSACTION;
                                END;

                            SET @SqlReturnSts = -1;
				
                            EXECUTE dbo.uspLogError @procParameters = @procParametersTmp, @userFriendly = 1;

                            BREAK;                         

                        END;

                END CATCH;

            END;

        RETURN @SqlReturnSts;
    END;
GO
/****** Object:  UserDefinedFunction [dbo].[DisplayName]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO


-- select dbo.DisplayName(AgtPrefix, AgtFirstName, AgtMiddle, AgtLastName, AgtSuffix, AgtEntityName, 11) from dbo.[Agent Codes] where AgtCode='AA0040785'
-- select dbo.DisplayName(AgtPrefix, AgtFirstName, AgtMiddle, AgtLastName, AgtSuffix, AgtEntityName, 12) from dbo.[Agent Codes] where AgtCode='AA0040785'
-- select dbo.DisplayName(AgtPrefix, AgtFirstName, AgtMiddle, AgtLastName, AgtSuffix, AgtEntityName, 21) from dbo.[Agent Codes] where AgtCode='AA0040785'
-- select dbo.DisplayName(AgtPrefix, AgtFirstName, AgtMiddle, AgtLastName, AgtSuffix, AgtEntityName, 31) from dbo.[Agent Codes] where AgtCode='AA0040785'

-- select dbo.DisplayName(Prefix, FirstName, Middle, LastName, Suffix, NULL, 11) from dbo.[MASTER] where PolNo='0006192813P1'
-- select dbo.DisplayName(Prefix, FirstName, Middle, LastName, Suffix, NULL, 12) from dbo.Addresses where PolNo='0061660855P1'

-- Erratic cases return an empty string
-- select dbo.DisplayName(NULL, NULL, NULL, NULL, NULL, NULL, 11) from dbo.[MASTER] where PolNo='0006192813P1'
-- select dbo.DisplayName(NULL, NULL, NULL, NULL, NULL, NULL, 100000) from dbo.[MASTER] where PolNo='0006192813P1'


-- The format contains 2 digits
-- The first digit specifies which components to include.
--		1 - Prefix First Middle Last Suffix
--		2 - First Middle Last 
--		3 - First Last
-- The second digit specifies the case
--		1 - Use whatever is passed in
--		2 - Upper case
--		3 - Camel case

CREATE FUNCTION [dbo].[DisplayName]
    (
      @Prefix VARCHAR(50) = NULL ,
      @First VARCHAR(50) = NULL ,
      @Middle VARCHAR(50) = NULL ,
      @Last VARCHAR(50) = NULL ,
      @Suffix VARCHAR(50) = NULL ,
      @EntityName VARCHAR(200) = NULL ,
      @Format INT
    )
RETURNS VARCHAR(250)
AS
    BEGIN

        RETURN

		-- (i.e. "entity name" or "mr first middle last iv")
		CASE WHEN @Format = 11 THEN

                CASE WHEN @EntityName IS NULL OR LEN(@EntityName) < 1 THEN
					LTRIM(RTRIM(
					LTRIM(RTRIM(ISNULL(@Prefix, ''))) + CASE WHEN @Prefix IS NULL THEN '' ELSE ' ' END
					+ LTRIM(RTRIM(ISNULL(@First, ''))) + CASE WHEN @First IS NULL THEN '' ELSE ' ' END
					+ LTRIM(RTRIM(ISNULL(@Middle, ''))) + CASE WHEN @Middle IS NULL THEN '' ELSE ' ' END
					+ LTRIM(RTRIM(ISNULL(@Last, ''))) + CASE WHEN @Last IS NULL THEN '' ELSE ' ' END
					+ LTRIM(RTRIM(ISNULL(@Suffix, '')))
					))
				ELSE LTRIM(RTRIM(@EntityName))
                END

		-- (i.e. "ENTITY NAME" or "MR FIRST MIDDLE LAST IV")
		WHEN @Format = 12 THEN

				UPPER(LTRIM(RTRIM(
                CASE WHEN @EntityName IS NULL OR LEN(@EntityName) < 1 THEN
					LTRIM(RTRIM(
					LTRIM(RTRIM(ISNULL(@Prefix, ''))) + CASE WHEN @Prefix IS NULL THEN '' ELSE ' ' END
					+ LTRIM(RTRIM(ISNULL(@First, ''))) + CASE WHEN @First IS NULL THEN '' ELSE ' ' END
					+ LTRIM(RTRIM(ISNULL(@Middle, ''))) + CASE WHEN @Middle IS NULL THEN '' ELSE ' ' END
					+ LTRIM(RTRIM(ISNULL(@Last, ''))) + CASE WHEN @Last IS NULL THEN '' ELSE ' ' END
					+ LTRIM(RTRIM(ISNULL(@Suffix, '')))
					))
				ELSE LTRIM(RTRIM(@EntityName))
                END
				)))

		-- (i.e. "entity name" or "first middle last")
		WHEN @Format = 21 THEN

                CASE WHEN @EntityName IS NULL OR LEN(@EntityName) < 1 THEN
					LTRIM(RTRIM(
					LTRIM(RTRIM(ISNULL(@First, ''))) + CASE WHEN @First IS NULL THEN '' ELSE ' ' END
					+ LTRIM(RTRIM(ISNULL(@Middle, ''))) + CASE WHEN @Middle IS NULL THEN '' ELSE ' ' END
					+ LTRIM(RTRIM(ISNULL(@Last, '')))
					))
				ELSE LTRIM(RTRIM(@EntityName))
                END

		-- (i.e. "ENTITY NAME" or "FIRST MIDDLE LAST")
		WHEN @Format = 22 THEN

				UPPER(LTRIM(RTRIM(
                CASE WHEN @EntityName IS NULL OR LEN(@EntityName) < 1 THEN
					LTRIM(RTRIM(
					LTRIM(RTRIM(ISNULL(@First, ''))) + CASE WHEN @First IS NULL THEN '' ELSE ' ' END
					+ LTRIM(RTRIM(ISNULL(@Middle, ''))) + CASE WHEN @Middle IS NULL THEN '' ELSE ' ' END
					+ LTRIM(RTRIM(ISNULL(@Last, '')))
					))
				ELSE LTRIM(RTRIM(@EntityName))
                END
				)))

		-- (i.e. "entity name" or "first last")
		WHEN @Format = 31 THEN

                CASE WHEN @EntityName IS NULL OR LEN(@EntityName) < 1 THEN
					LTRIM(RTRIM(
					LTRIM(RTRIM(ISNULL(@First, ''))) + CASE WHEN @First IS NULL THEN '' ELSE ' ' END
					+ LTRIM(RTRIM(ISNULL(@Last, '')))
					))
				ELSE LTRIM(RTRIM(@EntityName))
                END

		-- (i.e. "ENTITY NAME" or "FIRST LAST")
		WHEN @Format = 32 THEN

				UPPER(LTRIM(RTRIM(
                CASE WHEN @EntityName IS NULL OR LEN(@EntityName) < 1 THEN
					LTRIM(RTRIM(
					LTRIM(RTRIM(ISNULL(@First, ''))) + CASE WHEN @First IS NULL THEN '' ELSE ' ' END
					+ LTRIM(RTRIM(ISNULL(@Last, '')))
					))
				ELSE LTRIM(RTRIM(@EntityName))
                END
				)))

		-- Default to empty string
		ELSE ''
    END;

    END;




GO
/****** Object:  Table [dbo].[dba_errorLog]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[dba_errorLog](
	[errorLog_id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[errorType] [char](3) NULL,
	[errorDate] [datetime] NULL,
	[errorLine] [int] NULL,
	[errorMessage] [nvarchar](4000) NULL,
	[errorNumber] [int] NULL,
	[errorProcedure] [nvarchar](126) NULL,
	[procParameters] [nvarchar](4000) NULL,
	[errorSeverity] [int] NULL,
	[errorState] [int] NULL,
	[databaseName] [nvarchar](255) NULL,
	[systemUser] [nvarchar](255) NULL,
 CONSTRAINT [PK_errorLog_errorLogID] PRIMARY KEY CLUSTERED 
(
	[errorLog_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [qte].[Annuitant]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [qte].[Annuitant](
	[AnnuitantID] [int] IDENTITY(1,1) NOT NULL,
	[QuoteID] [int] NOT NULL,
	[FirstName] [varchar](50) NOT NULL,
	[LastName] [varchar](50) NOT NULL,
	[DOB] [date] NOT NULL,
	[RatedAge] [int] NOT NULL,
	[Gender] [char](1) NOT NULL,
 CONSTRAINT [PK_Annuitant] PRIMARY KEY CLUSTERED 
(
	[AnnuitantID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [qte].[Benefit]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [qte].[Benefit](
	[BenefitID] [int] IDENTITY(1,1) NOT NULL,
	[BenefitDescr] [varchar](50) NOT NULL,
	[UseJointAnnuitant] [bit] NOT NULL,
	[DropDownOrder] [int] NOT NULL,
 CONSTRAINT [PK_Benefit] PRIMARY KEY CLUSTERED 
(
	[BenefitID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [qte].[BenefitQuote]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [qte].[BenefitQuote](
	[BenefitQuoteID] [int] IDENTITY(1,1) NOT NULL,
	[QuoteID] [int] NOT NULL,
	[BenefitID] [int] NOT NULL,
	[PrimaryAnnuitantID] [int] NOT NULL,
	[JointAnnuitantID] [int] NOT NULL,
	[PaymentMode] [char](1) NOT NULL,
	[BenefitAmt] [decimal](18, 2) NULL,
	[PremiumAmt] [decimal](18, 2) NULL,
	[FirstPaymentDate] [date] NOT NULL,
	[CertainYears] [int] NOT NULL,
	[CertainMonths] [int] NOT NULL,
	[ImprovementPct] [decimal](5, 2) NOT NULL,
	[EndDate] [date] NULL,
 CONSTRAINT [PK_BenefitQuote] PRIMARY KEY CLUSTERED 
(
	[BenefitQuoteID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [qte].[Improvement]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [qte].[Improvement](
	[ImprovementID] [int] IDENTITY(1,1) NOT NULL,
	[ImprovementDescr] [varchar](50) NOT NULL,
	[ImprovementPct] [decimal](9, 6) NOT NULL,
	[DateCreated] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_Improvement] PRIMARY KEY CLUSTERED 
(
	[ImprovementID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [qte].[LifeExpMultiple]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [qte].[LifeExpMultiple](
	[AnnuitantID] [int] NOT NULL,
	[AnnuityYear] [int] NOT NULL,
	[UseImprovement] [bit] NOT NULL,
	[LifeExpMultipleQx] [float] NOT NULL,
	[LifeExpMultipleS] [float] NULL,
 CONSTRAINT [PK_MultipleTable] PRIMARY KEY CLUSTERED 
(
	[AnnuitantID] ASC,
	[AnnuityYear] ASC,
	[UseImprovement] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [qte].[Mortality]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [qte].[Mortality](
	[MortalityHdrID] [int] NOT NULL,
	[Age] [tinyint] NOT NULL,
	[Gender] [char](1) NOT NULL,
	[MortalityPct] [decimal](9, 6) NOT NULL,
 CONSTRAINT [PK_Mortality] PRIMARY KEY CLUSTERED 
(
	[MortalityHdrID] ASC,
	[Age] ASC,
	[Gender] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [qte].[MortalityHdr]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [qte].[MortalityHdr](
	[MortalityHdrID] [int] IDENTITY(1,1) NOT NULL,
	[MortalityDescr] [varchar](50) NOT NULL,
	[DateCreated] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_MortalityHdr] PRIMARY KEY CLUSTERED 
(
	[MortalityHdrID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [qte].[NumbersTable]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [qte].[NumbersTable](
	[Number] [int] IDENTITY(1,1) NOT NULL,
 CONSTRAINT [PK_NumbersTable] PRIMARY KEY CLUSTERED 
(
	[Number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [qte].[PaymentStream]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [qte].[PaymentStream](
	[PaymentStreamID] [int] IDENTITY(1,1) NOT NULL,
	[BenefitQuoteID] [int] NOT NULL,
	[AnnuityYear] [int] NULL,
	[AnnuityMonth] [int] NULL,
	[AnnuityAccumMonth] [int] NULL,
	[AnnuityDate] [date] NULL,
	[MakePayment] [bit] NULL,
	[CertainAmt] [float] NULL,
	[ContingentAmt] [float] NULL,
	[PaymentStreamS] [float] NULL,
	[PaymentValue] [float] NULL,
	[ExpectedT] [float] NULL,
	[ExpectedN] [float] NULL,
	[Guaranteed] [float] NULL,
	[BenefitAmt] [decimal](18, 2) NULL,
 CONSTRAINT [PK_PaymentStream] PRIMARY KEY CLUSTERED 
(
	[PaymentStreamID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [qte].[ProcedureLog]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [qte].[ProcedureLog](
	[ProcedureLogID] [int] IDENTITY(1,1) NOT NULL,
	[TransactionDate] [datetime2](7) NOT NULL,
	[ProcedureName] [varchar](100) NOT NULL,
	[RunStart] [datetime2](7) NOT NULL,
	[RunEnd] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_ProcedureLog] PRIMARY KEY CLUSTERED 
(
	[ProcedureLogID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [qte].[Quote]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [qte].[Quote](
	[QuoteID] [int] IDENTITY(1,1) NOT NULL,
	[QuoteDescr] [varchar](50) NOT NULL,
	[DateCreated] [datetime2](7) NOT NULL,
	[LastModified] [datetime2](7) NULL,
	[RateVersionID] [int] NOT NULL,
	[StlmtBrokerID] [int] NOT NULL,
	[PurchaseDate] [date] NOT NULL,
	[BudgetAmt] [decimal](18, 2) NOT NULL,
 CONSTRAINT [PK_Quote] PRIMARY KEY CLUSTERED 
(
	[QuoteID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [qte].[RateVersion]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [qte].[RateVersion](
	[RateVersionID] [int] IDENTITY(1,1) NOT NULL,
	[RateDescr] [varchar](50) NOT NULL,
	[SpotRateHdrID] [int] NOT NULL,
	[MortalityHdrID] [int] NOT NULL,
	[ImprovementID] [int] NOT NULL,
	[SpotWeightHdrID] [int] NOT NULL,
	[DateCreated] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_RateVersion] PRIMARY KEY CLUSTERED 
(
	[RateVersionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [qte].[SpotInterest]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [qte].[SpotInterest](
	[RateVersionID] [int] NOT NULL,
	[AnnuityAccumMonth] [int] NOT NULL,
	[AnnuityYear] [int] NOT NULL,
	[AnnuityMonth] [int] NOT NULL,
	[DiscountRate] [float] NULL,
	[SpotInterestVx] [float] NULL,
 CONSTRAINT [PK_SpotInterest] PRIMARY KEY CLUSTERED 
(
	[RateVersionID] ASC,
	[AnnuityAccumMonth] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [qte].[SpotRate]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [qte].[SpotRate](
	[SpotRateHdrID] [int] NOT NULL,
	[AnnuityYear] [int] NOT NULL,
	[SpotRate] [decimal](19, 17) NOT NULL,
 CONSTRAINT [PK_SpotRate_1] PRIMARY KEY CLUSTERED 
(
	[SpotRateHdrID] ASC,
	[AnnuityYear] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [qte].[SpotRateHdr]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [qte].[SpotRateHdr](
	[SpotRateHdrID] [int] IDENTITY(1,1) NOT NULL,
	[SpotRateDescr] [varchar](50) NOT NULL,
	[DateCreated] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_SpotRateHdr] PRIMARY KEY CLUSTERED 
(
	[SpotRateHdrID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [qte].[SpotWeight]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [qte].[SpotWeight](
	[SpotWeightHdrID] [int] NOT NULL,
	[AnnuityAccumMonth] [int] NOT NULL,
	[Weight1] [float] NOT NULL,
	[Weight2] [float] NOT NULL,
 CONSTRAINT [PK_SpotWeight] PRIMARY KEY CLUSTERED 
(
	[SpotWeightHdrID] ASC,
	[AnnuityAccumMonth] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [qte].[SpotWeightHdr]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [qte].[SpotWeightHdr](
	[SpotWeightHdrID] [int] IDENTITY(1,1) NOT NULL,
	[SpotWeightDescr] [varchar](50) NOT NULL,
	[DateCreated] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_SpotWeightHdr] PRIMARY KEY CLUSTERED 
(
	[SpotWeightHdrID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [qte].[StateCode]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [qte].[StateCode](
	[StateCode] [char](2) NOT NULL,
	[StateName] [varchar](50) NOT NULL,
 CONSTRAINT [PK_StateCode] PRIMARY KEY CLUSTERED 
(
	[StateCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [qte].[StlmtBroker]    Script Date: 3/7/2018 10:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [qte].[StlmtBroker](
	[StlmtBrokerID] [int] IDENTITY(1,1) NOT NULL,
	[FirstName] [varchar](50) NULL,
	[MiddleInitial] [char](1) NULL,
	[LastName] [varchar](50) NULL,
	[EntityName] [varchar](100) NULL,
	[AddrLine1] [varchar](100) NOT NULL,
	[AddrLine2] [varchar](100) NULL,
	[AddrLine3] [varchar](100) NULL,
	[City] [varchar](100) NOT NULL,
	[StateCode] [char](2) NOT NULL,
	[ZipCode5] [char](5) NOT NULL,
	[PhoneNum] [char](10) NOT NULL,
 CONSTRAINT [PK_StlmtBroker] PRIMARY KEY CLUSTERED 
(
	[StlmtBrokerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
SET IDENTITY_INSERT [dbo].[dba_errorLog] ON 

INSERT [dbo].[dba_errorLog] ([errorLog_id], [errorType], [errorDate], [errorLine], [errorMessage], [errorNumber], [errorProcedure], [procParameters], [errorSeverity], [errorState], [databaseName], [systemUser]) VALUES (1, N'sys', CAST(0x0000A80600B54640 AS DateTime), 79, N'Violation of UNIQUE KEY constraint ''IX_Annuitant_QuoteFirstLast''. Cannot insert duplicate key in object ''qte.Annuitant''. The duplicate key value is (1, Bill, Boppel).', 2627, N'uspUpsertAnnuitant', N'QuoteID = 1 DOB = 1965-01-01 FirstName = Bill LastName = Boppel RatedAge = 52 Gender = M', 14, 1, N'C:\USERS\BBOPP\DOCUMENTS\VISUAL STUDIO 2013\PROJECTS\STLMTQUOTE\STLMQUOTEWPF\IQSMASTER.MDF', N'AMR\bbopp')
INSERT [dbo].[dba_errorLog] ([errorLog_id], [errorType], [errorDate], [errorLine], [errorMessage], [errorNumber], [errorProcedure], [procParameters], [errorSeverity], [errorState], [databaseName], [systemUser]) VALUES (2, N'sys', CAST(0x0000A80600BB0AD0 AS DateTime), 67, N'Cannot insert the value NULL into column ''DOB'', table ''C:\USERS\BBOPP\DOCUMENTS\VISUAL STUDIO 2013\PROJECTS\STLMTQUOTE\STLMQUOTEWPF\IQSMASTER.MDF.qte.Annuitant''; column does not allow nulls. INSERT fails.', 515, N'uspUpsertAnnuitant', NULL, 16, 2, N'C:\USERS\BBOPP\DOCUMENTS\VISUAL STUDIO 2013\PROJECTS\STLMTQUOTE\STLMQUOTEWPF\IQSMASTER.MDF', N'AMR\bbopp')
INSERT [dbo].[dba_errorLog] ([errorLog_id], [errorType], [errorDate], [errorLine], [errorMessage], [errorNumber], [errorProcedure], [procParameters], [errorSeverity], [errorState], [databaseName], [systemUser]) VALUES (3, N'sys', CAST(0x0000A80600BF6FD0 AS DateTime), 44, N'Violation of UNIQUE KEY constraint ''IX_Annuitant_QuoteFirstLast''. Cannot insert duplicate key in object ''qte.Annuitant''. The duplicate key value is (1, Bill, Boppel).', 2627, N'uspUpsertAnnuitant', N'QuoteID = 1 AnnuitantID = 0 DOB = 1965-01-01 FirstName = Bill LastName = Boppel RatedAge = 52 Gender = M', 14, 1, N'C:\USERS\BBOPP\DOCUMENTS\VISUAL STUDIO 2013\PROJECTS\STLMTQUOTE\STLMQUOTEWPF\IQSMASTER.MDF', N'AMR\bbopp')
INSERT [dbo].[dba_errorLog] ([errorLog_id], [errorType], [errorDate], [errorLine], [errorMessage], [errorNumber], [errorProcedure], [procParameters], [errorSeverity], [errorState], [databaseName], [systemUser]) VALUES (4, N'sys', CAST(0x0000A80600C0CF60 AS DateTime), 44, N'Violation of UNIQUE KEY constraint ''IX_Annuitant_QuoteFirstLast''. Cannot insert duplicate key in object ''qte.Annuitant''. The duplicate key value is (1, Bill, Boppel).', 2627, N'uspUpsertAnnuitant', N'QuoteID = 1 AnnuitantID = 0 DOB = 1965-01-01 FirstName = Bill LastName = Boppel RatedAge = 52 Gender = M', 14, 1, N'C:\USERS\BBOPP\DOCUMENTS\VISUAL STUDIO 2013\PROJECTS\STLMTQUOTE\STLMQUOTEWPF\IQSMASTER.MDF', N'AMR\bbopp')
INSERT [dbo].[dba_errorLog] ([errorLog_id], [errorType], [errorDate], [errorLine], [errorMessage], [errorNumber], [errorProcedure], [procParameters], [errorSeverity], [errorState], [databaseName], [systemUser]) VALUES (5, N'sys', CAST(0x0000A80600C115B0 AS DateTime), 44, N'Violation of UNIQUE KEY constraint ''IX_Annuitant_QuoteFirstLast''. Cannot insert duplicate key in object ''qte.Annuitant''. The duplicate key value is (1, Bill, Boppel).', 2627, N'uspUpsertAnnuitant', N'QuoteID = 1 AnnuitantID = 0 DOB = 1965-01-01 FirstName = Bill LastName = Boppel RatedAge = 52 Gender = M', 14, 1, N'C:\USERS\BBOPP\DOCUMENTS\VISUAL STUDIO 2013\PROJECTS\STLMTQUOTE\STLMQUOTEWPF\IQSMASTER.MDF', N'AMR\bbopp')
INSERT [dbo].[dba_errorLog] ([errorLog_id], [errorType], [errorDate], [errorLine], [errorMessage], [errorNumber], [errorProcedure], [procParameters], [errorSeverity], [errorState], [databaseName], [systemUser]) VALUES (6, N'sys', CAST(0x0000A80600C115B0 AS DateTime), 44, N'Violation of UNIQUE KEY constraint ''IX_Annuitant_QuoteFirstLast''. Cannot insert duplicate key in object ''qte.Annuitant''. The duplicate key value is (1, Bill, Boppel).', 2627, N'uspUpsertAnnuitant', N'QuoteID = 1 AnnuitantID = 0 DOB = 1965-01-01 FirstName = Bill LastName = Boppel RatedAge = 52 Gender = M', 14, 1, N'C:\USERS\BBOPP\DOCUMENTS\VISUAL STUDIO 2013\PROJECTS\STLMTQUOTE\STLMQUOTEWPF\IQSMASTER.MDF', N'AMR\bbopp')
INSERT [dbo].[dba_errorLog] ([errorLog_id], [errorType], [errorDate], [errorLine], [errorMessage], [errorNumber], [errorProcedure], [procParameters], [errorSeverity], [errorState], [databaseName], [systemUser]) VALUES (7, N'sys', CAST(0x0000A80600C15C00 AS DateTime), 44, N'Violation of UNIQUE KEY constraint ''IX_Annuitant_QuoteFirstLast''. Cannot insert duplicate key in object ''qte.Annuitant''. The duplicate key value is (1, Bill, Boppel).', 2627, N'uspUpsertAnnuitant', N'QuoteID = 1 AnnuitantID = 0 DOB = 1965-01-01 FirstName = Bill LastName = Boppel RatedAge = 52 Gender = M', 14, 1, N'C:\USERS\BBOPP\DOCUMENTS\VISUAL STUDIO 2013\PROJECTS\STLMTQUOTE\STLMQUOTEWPF\IQSMASTER.MDF', N'AMR\bbopp')
SET IDENTITY_INSERT [dbo].[dba_errorLog] OFF
SET IDENTITY_INSERT [qte].[Benefit] ON 

INSERT [qte].[Benefit] ([BenefitID], [BenefitDescr], [UseJointAnnuitant], [DropDownOrder]) VALUES (1, N'Life', 0, 1)
INSERT [qte].[Benefit] ([BenefitID], [BenefitDescr], [UseJointAnnuitant], [DropDownOrder]) VALUES (2, N'Period Certain', 0, 2)
INSERT [qte].[Benefit] ([BenefitID], [BenefitDescr], [UseJointAnnuitant], [DropDownOrder]) VALUES (3, N'Lump Sum', 0, 3)
INSERT [qte].[Benefit] ([BenefitID], [BenefitDescr], [UseJointAnnuitant], [DropDownOrder]) VALUES (4, N'Temporary Life', 0, 4)
INSERT [qte].[Benefit] ([BenefitID], [BenefitDescr], [UseJointAnnuitant], [DropDownOrder]) VALUES (5, N'Joint Life', 1, 5)
INSERT [qte].[Benefit] ([BenefitID], [BenefitDescr], [UseJointAnnuitant], [DropDownOrder]) VALUES (6, N'Endowment', 0, 6)
INSERT [qte].[Benefit] ([BenefitID], [BenefitDescr], [UseJointAnnuitant], [DropDownOrder]) VALUES (7, N'Upfront Cash', 0, 7)
SET IDENTITY_INSERT [qte].[Benefit] OFF
SET IDENTITY_INSERT [qte].[Improvement] ON 

INSERT [qte].[Improvement] ([ImprovementID], [ImprovementDescr], [ImprovementPct], [DateCreated]) VALUES (1, N'20180222.i', CAST(0.005000 AS Decimal(9, 6)), CAST(0x0700E7AEEA41F43D0B AS DateTime2))
SET IDENTITY_INSERT [qte].[Improvement] OFF
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 0, N'F', CAST(0.000250 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 0, N'M', CAST(0.000500 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 1, N'F', CAST(0.000250 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 1, N'M', CAST(0.000500 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 2, N'F', CAST(0.000250 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 2, N'M', CAST(0.000500 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 3, N'F', CAST(0.000250 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 3, N'M', CAST(0.000500 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 4, N'F', CAST(0.000250 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 4, N'M', CAST(0.000500 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 5, N'F', CAST(0.000194 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 5, N'M', CAST(0.000377 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 6, N'F', CAST(0.000160 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 6, N'M', CAST(0.000350 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 7, N'F', CAST(0.000134 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 7, N'M', CAST(0.000333 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 8, N'F', CAST(0.000134 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 8, N'M', CAST(0.000352 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 9, N'F', CAST(0.000136 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 9, N'M', CAST(0.000368 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 10, N'F', CAST(0.000141 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 10, N'M', CAST(0.000382 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 11, N'F', CAST(0.000147 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 11, N'M', CAST(0.000394 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 12, N'F', CAST(0.000155 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 12, N'M', CAST(0.000405 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 13, N'F', CAST(0.000165 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 13, N'M', CAST(0.000415 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 14, N'F', CAST(0.000175 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 14, N'M', CAST(0.000425 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 15, N'F', CAST(0.000188 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 15, N'M', CAST(0.000435 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 16, N'F', CAST(0.000201 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 16, N'M', CAST(0.000446 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 17, N'F', CAST(0.000214 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 17, N'M', CAST(0.000458 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 18, N'F', CAST(0.000229 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 18, N'M', CAST(0.000472 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 19, N'F', CAST(0.000244 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 19, N'M', CAST(0.000488 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 20, N'F', CAST(0.000260 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 20, N'M', CAST(0.000505 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 21, N'F', CAST(0.000276 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 21, N'M', CAST(0.000525 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 22, N'F', CAST(0.000293 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 22, N'M', CAST(0.000546 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 23, N'F', CAST(0.000311 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 23, N'M', CAST(0.000570 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 24, N'F', CAST(0.000330 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 24, N'M', CAST(0.000596 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 25, N'F', CAST(0.000349 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 25, N'M', CAST(0.000622 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 26, N'F', CAST(0.000368 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 26, N'M', CAST(0.000650 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 27, N'F', CAST(0.000387 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 27, N'M', CAST(0.000677 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 28, N'F', CAST(0.000405 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 28, N'M', CAST(0.000704 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 29, N'F', CAST(0.000423 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 29, N'M', CAST(0.000731 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 30, N'F', CAST(0.000441 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 30, N'M', CAST(0.000759 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 31, N'F', CAST(0.000460 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 31, N'M', CAST(0.000786 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 32, N'F', CAST(0.000479 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 32, N'M', CAST(0.000814 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 33, N'F', CAST(0.000499 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 33, N'M', CAST(0.000843 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 34, N'F', CAST(0.000521 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 34, N'M', CAST(0.000876 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 35, N'F', CAST(0.000545 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 35, N'M', CAST(0.000917 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 36, N'F', CAST(0.000574 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 36, N'M', CAST(0.000968 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 37, N'F', CAST(0.000607 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 37, N'M', CAST(0.001032 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 38, N'F', CAST(0.000646 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 38, N'M', CAST(0.001114 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 39, N'F', CAST(0.000691 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 39, N'M', CAST(0.001216 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 40, N'F', CAST(0.000742 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 40, N'M', CAST(0.001341 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 41, N'F', CAST(0.000801 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 41, N'M', CAST(0.001492 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 42, N'F', CAST(0.000867 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 42, N'M', CAST(0.001673 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 43, N'F', CAST(0.000942 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 43, N'M', CAST(0.001886 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 44, N'F', CAST(0.001026 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 44, N'M', CAST(0.002129 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 45, N'F', CAST(0.001122 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 45, N'M', CAST(0.002399 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 46, N'F', CAST(0.001231 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 46, N'M', CAST(0.002693 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 47, N'F', CAST(0.001356 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 47, N'M', CAST(0.003009 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 48, N'F', CAST(0.001499 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 48, N'M', CAST(0.003343 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 49, N'F', CAST(0.001657 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 49, N'M', CAST(0.003694 AS Decimal(9, 6)))
GO
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 50, N'F', CAST(0.001830 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 50, N'M', CAST(0.004057 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 51, N'F', CAST(0.002016 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 51, N'M', CAST(0.004431 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 52, N'F', CAST(0.002215 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 52, N'M', CAST(0.004812 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 53, N'F', CAST(0.002426 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 53, N'M', CAST(0.005198 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 54, N'F', CAST(0.002650 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 54, N'M', CAST(0.005591 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 55, N'F', CAST(0.002891 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 55, N'M', CAST(0.005994 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 56, N'F', CAST(0.003151 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 56, N'M', CAST(0.006409 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 57, N'F', CAST(0.003432 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 57, N'M', CAST(0.006839 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 58, N'F', CAST(0.003739 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 58, N'M', CAST(0.007290 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 59, N'F', CAST(0.004081 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 59, N'M', CAST(0.007782 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 60, N'F', CAST(0.004467 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 60, N'M', CAST(0.008338 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 61, N'F', CAST(0.004908 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 61, N'M', CAST(0.008983 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 62, N'F', CAST(0.005413 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 62, N'M', CAST(0.009740 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 63, N'F', CAST(0.005990 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 63, N'M', CAST(0.010630 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 64, N'F', CAST(0.006633 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 64, N'M', CAST(0.011664 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 65, N'F', CAST(0.007336 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 65, N'M', CAST(0.012851 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 66, N'F', CAST(0.008090 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 66, N'M', CAST(0.014199 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 67, N'F', CAST(0.008888 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 67, N'M', CAST(0.015717 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 68, N'F', CAST(0.009731 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 68, N'M', CAST(0.017414 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 69, N'F', CAST(0.010653 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 69, N'M', CAST(0.019296 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 70, N'F', CAST(0.011697 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 70, N'M', CAST(0.021371 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 71, N'F', CAST(0.012905 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 71, N'M', CAST(0.023647 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 72, N'F', CAST(0.014319 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 72, N'M', CAST(0.026131 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 73, N'F', CAST(0.015980 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 73, N'M', CAST(0.028835 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 74, N'F', CAST(0.017909 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 74, N'M', CAST(0.031794 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 75, N'F', CAST(0.020127 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 75, N'M', CAST(0.035046 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 76, N'F', CAST(0.022654 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 76, N'M', CAST(0.038631 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 77, N'F', CAST(0.025509 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 77, N'M', CAST(0.042587 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 78, N'F', CAST(0.028717 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 78, N'M', CAST(0.046951 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 79, N'F', CAST(0.032328 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 79, N'M', CAST(0.051755 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 80, N'F', CAST(0.036395 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 80, N'M', CAST(0.057026 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 81, N'F', CAST(0.040975 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 81, N'M', CAST(0.062791 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 82, N'F', CAST(0.046121 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 82, N'M', CAST(0.069081 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 83, N'F', CAST(0.051889 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 83, N'M', CAST(0.075908 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 84, N'F', CAST(0.058336 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 84, N'M', CAST(0.083230 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 85, N'F', CAST(0.065518 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 85, N'M', CAST(0.090987 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 86, N'F', CAST(0.073493 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 86, N'M', CAST(0.099122 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 87, N'F', CAST(0.082318 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 87, N'M', CAST(0.107577 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 88, N'F', CAST(0.092017 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 88, N'M', CAST(0.116316 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 89, N'F', CAST(0.102491 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 89, N'M', CAST(0.125394 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 90, N'F', CAST(0.113605 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 90, N'M', CAST(0.134887 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 91, N'F', CAST(0.125227 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 91, N'M', CAST(0.144873 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 92, N'F', CAST(0.137222 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 92, N'M', CAST(0.155429 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 93, N'F', CAST(0.149462 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 93, N'M', CAST(0.166629 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 94, N'F', CAST(0.161834 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 94, N'M', CAST(0.178537 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 95, N'F', CAST(0.174228 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 95, N'M', CAST(0.191214 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 96, N'F', CAST(0.186535 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 96, N'M', CAST(0.204721 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 97, N'F', CAST(0.198646 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 97, N'M', CAST(0.219120 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 98, N'F', CAST(0.211102 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 98, N'M', CAST(0.234735 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 99, N'F', CAST(0.224445 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 99, N'M', CAST(0.251889 AS Decimal(9, 6)))
GO
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 100, N'F', CAST(0.239215 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 100, N'M', CAST(0.270906 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 101, N'F', CAST(0.255953 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 101, N'M', CAST(0.292111 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 102, N'F', CAST(0.275201 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 102, N'M', CAST(0.315826 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 103, N'F', CAST(0.297500 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 103, N'M', CAST(0.342377 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 104, N'F', CAST(0.323390 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 104, N'M', CAST(0.372086 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 105, N'F', CAST(0.353414 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 105, N'M', CAST(0.405278 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 106, N'F', CAST(0.388111 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 106, N'M', CAST(0.442277 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 107, N'F', CAST(0.428023 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 107, N'M', CAST(0.483406 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 108, N'F', CAST(0.473692 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 108, N'M', CAST(0.528989 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 109, N'F', CAST(0.525658 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 109, N'M', CAST(0.579351 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 110, N'F', CAST(0.584462 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 110, N'M', CAST(0.634814 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 111, N'F', CAST(0.650646 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 111, N'M', CAST(0.695704 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 112, N'F', CAST(0.724750 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 112, N'M', CAST(0.762343 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 113, N'F', CAST(0.807316 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 113, N'M', CAST(0.835056 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 114, N'F', CAST(0.898885 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 114, N'M', CAST(0.914167 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 115, N'F', CAST(1.000000 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 115, N'M', CAST(1.000000 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 116, N'F', CAST(1.000000 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 116, N'M', CAST(1.000000 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 117, N'F', CAST(1.000000 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 117, N'M', CAST(1.000000 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 118, N'F', CAST(1.000000 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 118, N'M', CAST(1.000000 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 119, N'F', CAST(1.000000 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 119, N'M', CAST(1.000000 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 120, N'F', CAST(1.000000 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 120, N'M', CAST(1.000000 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 121, N'F', CAST(1.000000 AS Decimal(9, 6)))
INSERT [qte].[Mortality] ([MortalityHdrID], [Age], [Gender], [MortalityPct]) VALUES (1, 121, N'M', CAST(1.000000 AS Decimal(9, 6)))
SET IDENTITY_INSERT [qte].[MortalityHdr] ON 

INSERT [qte].[MortalityHdr] ([MortalityHdrID], [MortalityDescr], [DateCreated]) VALUES (1, N'20180222.mt', CAST(0x072035AFEA41F43D0B AS DateTime2))
SET IDENTITY_INSERT [qte].[MortalityHdr] OFF
SET IDENTITY_INSERT [qte].[RateVersion] ON 

INSERT [qte].[RateVersion] ([RateVersionID], [RateDescr], [SpotRateHdrID], [MortalityHdrID], [ImprovementID], [SpotWeightHdrID], [DateCreated]) VALUES (1, N'20180222.rv', 1, 1, 1, 1, CAST(0x079046B0EA41F43D0B AS DateTime2))
SET IDENTITY_INSERT [qte].[RateVersion] OFF
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 0, 1, 0, 0, 1)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1, 1, 1, 0.006075, 0.99949541090158278)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 2, 1, 2, 0.01215, 0.99798923548130436)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 3, 1, 3, 0.013365, 0.9966863831210937)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 4, 1, 4, 0.01458, 0.99518671473663234)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 5, 1, 5, 0.015795, 0.99349146782014774)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 6, 1, 6, 0.017009999999999997, 0.99160198706052027)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 7, 1, 7, 0.018224999999999998, 0.98951977636889032)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 8, 1, 8, 0.01944, 0.98724640019994037)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 9, 1, 9, 0.020655, 0.98478352498881228)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 10, 1, 10, 0.02187, 0.98213298103548519)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 11, 1, 11, 0.023084999999999998, 0.97929664300247632)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 12, 1, 12, 0.0243, 0.9762764814995607)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 13, 2, 1, 0.024577170589401679, 0.974039582411455)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 14, 2, 2, 0.024854341178803366, 0.97176407094852413)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 15, 2, 3, 0.02513151176820505, 0.96945023552778431)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 16, 2, 4, 0.025408682357606734, 0.96709844083893781)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 17, 2, 5, 0.025685852947008415, 0.96470898400889937)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 18, 2, 6, 0.0259630235364101, 0.9622821655017425)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 19, 2, 7, 0.026240194125811783, 0.95981836365246409)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 20, 2, 8, 0.026517364715213463, 0.95731788719484212)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 21, 2, 9, 0.026794535304615147, 0.95478104800807062)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 22, 2, 10, 0.027071705894016831, 0.9522082373714994)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 23, 2, 11, 0.027348876483418511, 0.94959977498181081)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 24, 2, 12, 0.0276260470728202, 0.94695598348448)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 25, 3, 1, 0.027862478767088857, 0.94435523894277107)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 26, 3, 2, 0.028098910461357512, 0.94172563737133785)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 27, 3, 3, 0.028335342155626175, 0.93906744601371517)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 28, 3, 4, 0.028571773849894833, 0.93638101302478693)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 29, 3, 5, 0.028808205544163492, 0.93366661040686749)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 30, 3, 6, 0.029044637238432147, 0.93092451183282365)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 31, 3, 7, 0.029281068932700809, 0.92815507297385524)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 32, 3, 8, 0.029517500626969465, 0.92535857192996474)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 33, 3, 9, 0.029753932321238127, 0.92253528833314491)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 34, 3, 10, 0.029990364015506785, 0.91968558484220164)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 35, 3, 11, 0.030226795709775437, 0.916809745180803)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 36, 3, 12, 0.0304632274040441, 0.91390805446470158)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 37, 4, 1, 0.030654457951979245, 0.91110407476794164)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 38, 4, 2, 0.0308456884999144, 0.90828070661405014)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 39, 4, 3, 0.03103691904784955, 0.90543816391133658)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 40, 4, 4, 0.0312281495957847, 0.90257674445043712)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 41, 4, 5, 0.031419380143719845, 0.89969666406370152)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 42, 4, 6, 0.031610610691654994, 0.89679813913777007)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 43, 4, 7, 0.031801841239590151, 0.89388147054983946)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 44, 4, 8, 0.0319930717875253, 0.89094687640333148)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 45, 4, 9, 0.032184302335460442, 0.88799457527490167)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 46, 4, 10, 0.0323755328833956, 0.88502487079482106)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 47, 4, 11, 0.032566763431330747, 0.8820379830493239)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 48, 4, 12, 0.0327579939792659, 0.87903413251701756)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 49, 5, 1, 0.032949224527201046, 0.87601362524802129)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 50, 5, 2, 0.033140455075136195, 0.87297668302371356)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 51, 5, 3, 0.033331685623071344, 0.86992352793732719)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 52, 5, 4, 0.0335229161710065, 0.8668544681264031)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 53, 5, 5, 0.03371414671894165, 0.863769726780875)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 54, 5, 6, 0.0339053772668768, 0.86066952732248825)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 55, 5, 7, 0.034096607814811948, 0.85755417964510638)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 56, 5, 8, 0.0342878383627471, 0.85442390806217872)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 57, 5, 9, 0.034479068910682246, 0.85127893703953927)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 58, 5, 10, 0.0346702994586174, 0.84811957789812586)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 59, 5, 11, 0.034861530006552545, 0.84494605579187487)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 60, 5, 12, 0.0350527605544877, 0.84175859594843561)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 61, 6, 1, 0.035210910354373876, 0.83869373560471649)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 62, 6, 2, 0.03536906015426005, 0.83561885710078454)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 63, 6, 3, 0.035527209954146224, 0.83253412849380348)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 64, 6, 4, 0.0356853597540324, 0.8294398049798174)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 65, 6, 5, 0.03584350955391858, 0.82633605454486525)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 66, 6, 6, 0.036001659353804755, 0.82322304502740973)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 67, 6, 7, 0.036159809153690929, 0.82010103150472446)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 68, 6, 8, 0.0363179589535771, 0.81697018162044122)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 69, 6, 9, 0.036476108753463278, 0.81383066282664618)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 70, 6, 10, 0.036634258553349452, 0.81068272988018986)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 71, 6, 11, 0.036792408353235627, 0.807526549916446)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 72, 6, 12, 0.0369505581531218, 0.80436228983609526)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 73, 7, 1, 0.037025374619674638, 0.80158194150916307)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 74, 7, 2, 0.037100191086227467, 0.79880162401351218)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 75, 7, 3, 0.037175007552780304, 0.79602137578880849)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 76, 7, 4, 0.037249824019333133, 0.79324132223590449)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 77, 7, 5, 0.037324640485885963, 0.7904615012501871)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 78, 7, 6, 0.0373994569524388, 0.78768195065115021)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 79, 7, 7, 0.037474273418991629, 0.78490279481180736)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 80, 7, 8, 0.037549089885544465, 0.78212407099230652)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 81, 7, 9, 0.0376239063520973, 0.77934581637477829)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 82, 7, 10, 0.037698722818650131, 0.77656815427684722)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 83, 7, 11, 0.03777353928520296, 0.7737911213066917)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 84, 7, 12, 0.0378483557517558, 0.77101475399249242)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 85, 8, 1, 0.037871230465363809, 0.76851155339841559)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 86, 8, 2, 0.037894105178971828, 0.76601366858798381)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 87, 8, 3, 0.037916979892579854, 0.76352107226497745)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 88, 8, 4, 0.037939854606187866, 0.76103382239112616)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 89, 8, 5, 0.037962729319795878, 0.75855189146854241)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 90, 8, 6, 0.0379856040334039, 0.7560752522397336)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 91, 8, 7, 0.038008478747011916, 0.7536039620241255)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 92, 8, 8, 0.038031353460619928, 0.75113799336398346)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 93, 8, 9, 0.03805422817422794, 0.74867731904148849)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 94, 8, 10, 0.038077102887835966, 0.74622199573711567)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 95, 8, 11, 0.038099977601443985, 0.74377199603424737)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 96, 8, 12, 0.038122852315052, 0.74132729275568665)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 97, 9, 1, 0.038145727028660009, 0.73888794194634855)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 98, 9, 2, 0.038168601742268014, 0.73645391623169487)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 99, 9, 3, 0.038191476455876019, 0.73402518847611142)
GO
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 100, 9, 4, 0.038214351169484032, 0.731601814092366)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 101, 9, 5, 0.038237225883092044, 0.729183765748972)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 102, 9, 6, 0.038260100596700049, 0.72677101635285413)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 103, 9, 7, 0.038282975310308054, 0.72436362068809024)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 104, 9, 8, 0.038305850023916066, 0.721961551467209)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 105, 9, 9, 0.038328724737524078, 0.71956478164063542)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 106, 9, 10, 0.038351599451132083, 0.71717336536724341)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 107, 9, 11, 0.038374474164740095, 0.71478727540454978)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 108, 9, 12, 0.0383973488783481, 0.71240648474744406)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 109, 10, 1, 0.038420223591956119, 0.710031046933104)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 110, 10, 2, 0.038443098305564138, 0.70766093476501335)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 111, 10, 3, 0.038465973019172151, 0.70529612128348806)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 112, 10, 4, 0.03848884773278017, 0.70293665940755856)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 113, 10, 5, 0.038511722446388182, 0.70058252198764637)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 114, 10, 6, 0.0385345971599962, 0.69823368211046066)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 115, 10, 7, 0.03855747187360422, 0.69589019208046021)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 116, 10, 8, 0.038580346587212232, 0.69355202479597555)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 117, 10, 9, 0.038603221300820251, 0.69121915339108042)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 118, 10, 10, 0.03862609601442827, 0.68889162955926131)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 119, 10, 11, 0.038648970728036282, 0.68656942624773976)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 120, 10, 12, 0.0386718454416443, 0.68425251663891373)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 121, 11, 1, 0.0386879552283191, 0.68198573776392657)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 122, 11, 2, 0.038704065014993905, 0.67972471282522351)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 123, 11, 3, 0.0387201748016687, 0.677469408709446)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 124, 11, 4, 0.0387362845883435, 0.67521986956771107)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 125, 11, 5, 0.0387523943750183, 0.67297606217088934)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 126, 11, 6, 0.038768504161693106, 0.67073795356941057)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 127, 11, 7, 0.0387846139483679, 0.66850558740462329)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 128, 11, 8, 0.0388007237350427, 0.66627893061250476)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 129, 11, 9, 0.038816833521717505, 0.66405795040725057)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 130, 11, 10, 0.0388329433083923, 0.66184268992441309)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 131, 11, 11, 0.038849053095067108, 0.65963311626504939)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 132, 11, 12, 0.0388651628817419, 0.65742919680709566)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 133, 12, 1, 0.038881272668416705, 0.65523097418426723)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 134, 12, 2, 0.038897382455091507, 0.65303841566267407)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 135, 12, 3, 0.0389134922417663, 0.65085148878395671)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 136, 12, 4, 0.0389296020284411, 0.64867023568395432)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 137, 12, 5, 0.038945711815115906, 0.64649462379378753)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 138, 12, 6, 0.0389618216017907, 0.64432462081876385)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 139, 12, 7, 0.0389779313884655, 0.64216026840079488)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 140, 12, 8, 0.0389940411751403, 0.64000153413596816)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 141, 12, 9, 0.0390101509618151, 0.63784838589321335)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 142, 12, 10, 0.0390262607484899, 0.63570086482445487)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 143, 12, 11, 0.039042370535164704, 0.63355893869069746)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 144, 12, 12, 0.0390584803218395, 0.63142257552444248)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 145, 13, 1, 0.0390745901085143, 0.62929181599155859)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 146, 13, 2, 0.0390906998951891, 0.62716662801791256)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 147, 13, 3, 0.0391068096818639, 0.62504697979952029)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 148, 13, 4, 0.0391229194685387, 0.62293291152011832)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 149, 13, 5, 0.0391390292552135, 0.62082439127037514)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 150, 13, 6, 0.0391551390418883, 0.61872138740975413)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 151, 13, 7, 0.0391712488285631, 0.616623939643778)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 152, 13, 8, 0.0391873586152379, 0.61453201622784648)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 153, 13, 9, 0.039203468401912696, 0.61244558568480667)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 154, 13, 10, 0.039219578188587505, 0.61036468724586723)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 155, 13, 11, 0.0392356879752623, 0.60828928933108706)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 156, 13, 12, 0.0392517977619371, 0.60621936062662285)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 157, 14, 1, 0.039267907548611904, 0.60415493989326385)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 158, 14, 2, 0.0392840173352867, 0.60209599571564854)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 159, 14, 3, 0.0393001271219615, 0.6000424969431627)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 160, 14, 4, 0.0393162369086363, 0.59799448187006132)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 161, 14, 5, 0.0393323466953111, 0.59595191924547664)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 162, 14, 6, 0.0393484564819859, 0.59391477808193749)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 163, 14, 7, 0.0393645662686607, 0.59188309621103885)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 164, 14, 8, 0.039380676055335496, 0.58985684254631521)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 165, 14, 9, 0.0393967858420103, 0.58783598626334621)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 166, 14, 10, 0.0394128956286851, 0.58582056473493282)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 167, 14, 11, 0.039429005415359895, 0.58381054703890867)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 168, 14, 12, 0.0394451152020347, 0.58180590251381126)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 169, 15, 1, 0.0394612249887095, 0.57980666807749726)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 170, 15, 2, 0.039477334775384294, 0.57781281297200082)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 171, 15, 3, 0.0394934445620591, 0.57582430669870821)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 172, 15, 4, 0.0395095543487339, 0.5738411857243757)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 173, 15, 5, 0.0395256641354087, 0.57186341945512809)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 174, 15, 6, 0.0395417739220835, 0.56989097755509011)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 175, 15, 7, 0.0395578837087583, 0.56792389604374849)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 176, 15, 8, 0.0395739934954331, 0.56596214449120308)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 177, 15, 9, 0.0395901032821079, 0.56400569272420087)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 178, 15, 10, 0.039606213068782696, 0.56205457631877853)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 179, 15, 11, 0.0396223228554575, 0.56010876500888862)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 180, 15, 12, 0.0396384326421323, 0.55816822878377848)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 181, 16, 1, 0.039654542428807095, 0.556233002779842)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 182, 16, 2, 0.039670652215481904, 0.55430305689475678)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 183, 16, 3, 0.0396867620021567, 0.55237836128014417)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 184, 16, 4, 0.0397028717888315, 0.55045895063654537)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 185, 16, 5, 0.0397189815755063, 0.548544795025234)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 186, 16, 6, 0.0397350913621811, 0.546635864760068)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 187, 16, 7, 0.039751201148855907, 0.54473219410952434)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 188, 16, 8, 0.0397673109355307, 0.54283375329832706)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 189, 16, 9, 0.039783420722205504, 0.54094051280243238)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 190, 16, 10, 0.0397995305088803, 0.53905250646202385)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 191, 16, 11, 0.0398156402955551, 0.5371697046651297)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 192, 16, 12, 0.0398317500822299, 0.53529207804965817)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 193, 17, 1, 0.039847859868904704, 0.53341966003125729)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 194, 17, 2, 0.0398639696555795, 0.5315524211611069)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 195, 17, 3, 0.0398800794422543, 0.52969033223891582)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 196, 17, 4, 0.0398961892289291, 0.52783342625954077)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 197, 17, 5, 0.0399122990156039, 0.52598167393715545)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 198, 17, 6, 0.0399284088022787, 0.52413504623311058)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 199, 17, 7, 0.0399445185889535, 0.52229357572520374)
GO
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 200, 17, 8, 0.0399606283756283, 0.52045723329043936)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 201, 17, 9, 0.0399767381623031, 0.51862599005164123)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 202, 17, 10, 0.039992847948977894, 0.51679987817327067)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 203, 17, 11, 0.040008957735652696, 0.51497886869498932)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 204, 17, 12, 0.0400250675223275, 0.51316293290092907)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 205, 18, 1, 0.0400411773090023, 0.51135210254591446)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 206, 18, 2, 0.040057287095677095, 0.50954634883208916)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 207, 18, 3, 0.0400733968823519, 0.50774564320471771)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 208, 18, 4, 0.0400895066690267, 0.505950017012678)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 209, 18, 5, 0.0401056164557015, 0.50415944162041348)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 210, 18, 6, 0.0401217262423763, 0.50237388863413956)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 211, 18, 7, 0.0401378360290511, 0.50059338900046368)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 212, 18, 8, 0.0401539458157259, 0.49881791424594046)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 213, 18, 9, 0.0401700556024007, 0.49704743613754854)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 214, 18, 10, 0.0401861653890755, 0.49528198522328704)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 215, 18, 11, 0.0402022751757503, 0.49352153319162723)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 216, 18, 12, 0.0402183849624251, 0.4917660519701173)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 217, 19, 1, 0.0402344947490999, 0.49001557171179738)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 218, 19, 2, 0.040250604535774705, 0.48827006426684938)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 219, 19, 3, 0.0402667143224495, 0.48652950172319692)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 220, 19, 4, 0.0402828241091243, 0.48479391384255038)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 221, 19, 5, 0.040298933895799104, 0.4830632726366012)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 222, 19, 6, 0.0403150436824739, 0.48133755035343767)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 223, 19, 7, 0.040331153469148708, 0.47961677636705985)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 224, 19, 8, 0.0403472632558235, 0.47790092285045666)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 225, 19, 9, 0.0403633730424983, 0.47618996221166937)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 226, 19, 10, 0.040379482829173106, 0.47448392344059076)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 227, 19, 11, 0.0403955926158479, 0.4727827788712885)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 228, 19, 12, 0.0404117024025227, 0.47108650107154)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 229, 20, 1, 0.040427812189197505, 0.46939511865071804)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 230, 20, 2, 0.0404439219758723, 0.467708604103745)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 231, 20, 3, 0.040460031762547095, 0.46602693015791097)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 232, 20, 4, 0.040476141549221904, 0.46435012504564105)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 233, 20, 5, 0.040492251335896706, 0.46267816142248192)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 234, 20, 6, 0.0405083611225715, 0.46101101217500973)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 235, 20, 7, 0.040524470909246296, 0.45934870516225207)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 236, 20, 8, 0.0405405806959211, 0.45769121320014994)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 237, 20, 9, 0.040556690482595907, 0.45603850933432671)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 238, 20, 10, 0.0405728002692707, 0.45439062105395911)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 239, 20, 11, 0.0405889100559455, 0.45274752133513441)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 240, 20, 12, 0.0406050198426203, 0.4511091833822849)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 241, 21, 1, 0.040617113841040518, 0.44951047107982334)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 242, 21, 2, 0.040629207839460731, 0.44791655815484077)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 243, 21, 3, 0.04064130183788095, 0.44632741597910031)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 244, 21, 4, 0.040653395836301169, 0.44474306933413443)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 245, 21, 5, 0.040665489834721381, 0.44316348955480783)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 246, 21, 6, 0.0406775838331416, 0.44158864821813842)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 247, 21, 7, 0.04068967783156182, 0.4400185697904534)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 248, 21, 8, 0.040701771829982032, 0.4384532258126082)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 249, 21, 9, 0.040713865828402251, 0.43689258806592557)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 250, 21, 10, 0.040725959826822471, 0.43533668070468751)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 251, 21, 11, 0.040738053825242683, 0.4337854754747848)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 252, 21, 12, 0.0407501478236629, 0.43223894436088883)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 253, 22, 1, 0.040762241822083115, 0.43069711120837906)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 254, 22, 2, 0.040774335820503334, 0.42915994796722573)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 255, 22, 3, 0.040786429818923553, 0.42762742682448884)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 256, 22, 4, 0.040798523817343772, 0.42609957131977172)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 257, 22, 5, 0.040810617815763985, 0.42457635360615709)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 258, 22, 6, 0.0408227118141842, 0.42305774607214447)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 259, 22, 7, 0.040834805812604423, 0.42154377195466075)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 260, 22, 8, 0.040846899811024635, 0.42003440360893712)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 261, 22, 9, 0.040858993809444848, 0.41852961362396413)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 262, 22, 10, 0.040871087807865067, 0.41702942493706585)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 263, 22, 11, 0.040883181806285279, 0.41553381010466417)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 264, 22, 12, 0.0408952758047055, 0.41404274191528029)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 265, 23, 1, 0.040907369803125711, 0.4125562430096994)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 266, 23, 2, 0.040919463801545937, 0.41107428614457042)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 267, 23, 3, 0.040931557799966149, 0.4095968443069905)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 268, 23, 4, 0.040943651798386362, 0.40812393984424272)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 269, 23, 5, 0.040955745796806588, 0.40665554571224116)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 270, 23, 6, 0.0409678397952268, 0.40519163509570238)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 271, 23, 7, 0.040979933793647019, 0.4037322300514285)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 272, 23, 8, 0.040992027792067232, 0.4022773037336313)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 273, 23, 9, 0.041004121790487451, 0.40082682952369614)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 274, 23, 10, 0.04101621578890767, 0.399380829190932)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 275, 23, 11, 0.041028309787327882, 0.39793927608689261)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 276, 23, 12, 0.0410404037857481, 0.396502143788676)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 277, 24, 1, 0.041052497784168314, 0.39506945378106828)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 278, 24, 2, 0.041064591782588533, 0.39364117961200973)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 279, 24, 3, 0.041076685781008752, 0.39221729505335079)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 280, 24, 4, 0.041088779779428965, 0.39079782130831)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 281, 24, 5, 0.041100873777849184, 0.38938273212024671)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 282, 24, 6, 0.0411129677762694, 0.38797200145481586)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 283, 24, 7, 0.041125061774689615, 0.38656565023659606)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 284, 24, 8, 0.041137155773109835, 0.385163652403403)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 285, 24, 9, 0.041149249771530047, 0.38376598211374813)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 286, 24, 10, 0.041161343769950266, 0.38237266001647269)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 287, 24, 11, 0.041173437768370479, 0.38098366024289188)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 288, 24, 12, 0.0411855317667907, 0.37959895714341435)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 289, 25, 1, 0.0411976257652109, 0.37821857109403717)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 290, 25, 2, 0.041209719763631115, 0.37684247641861268)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 291, 25, 3, 0.041221813762051321, 0.37547064765849353)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 292, 25, 4, 0.041233907760471533, 0.37410310491969861)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 293, 25, 5, 0.041246001758891739, 0.37273982271765749)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 294, 25, 6, 0.041258095757311951, 0.37138077578371392)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 295, 25, 7, 0.041270189755732156, 0.37002598395675385)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 296, 25, 8, 0.041282283754152362, 0.36867542194282393)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 297, 25, 9, 0.041294377752572574, 0.367329064662307)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 298, 25, 10, 0.041306471750992779, 0.36598693168977964)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 299, 25, 11, 0.041318565749412985, 0.36464899792094674)
GO
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 300, 25, 12, 0.0413306597478332, 0.363315238464278)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 301, 26, 1, 0.041342753746253409, 0.36198567263284348)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 302, 26, 2, 0.041354847744673635, 0.36066027551104751)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 303, 26, 3, 0.041366941743093848, 0.35933902239449539)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 304, 26, 4, 0.04137903574151406, 0.35802193233753238)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 305, 26, 5, 0.041391129739934286, 0.35670898061230394)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 306, 26, 6, 0.0414032237383545, 0.35540014270059817)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 307, 26, 7, 0.041415317736774718, 0.35409543740080218)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 308, 26, 8, 0.04142741173519493, 0.35279484017183921)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 309, 26, 9, 0.041439505733615149, 0.35149832668073339)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 310, 26, 10, 0.041451599732035369, 0.35020591547264812)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 311, 26, 11, 0.041463693730455581, 0.34891758219233288)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 312, 26, 12, 0.0414757877288758, 0.34763330269109644)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 313, 27, 1, 0.041487881727296012, 0.34635309526359553)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 314, 27, 2, 0.041499975725716239, 0.34507693573945519)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 315, 27, 3, 0.041512069724136451, 0.343804800153314)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 316, 27, 4, 0.041524163722556663, 0.34253670655202406)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 317, 27, 5, 0.041536257720976889, 0.34127263094912469)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 318, 27, 6, 0.0415483517193971, 0.34001254956164129)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 319, 27, 7, 0.041560445717817321, 0.33875648019129739)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 320, 27, 8, 0.041572539716237533, 0.33750439903459112)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 321, 27, 9, 0.041584633714657752, 0.33625628248998746)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 322, 27, 10, 0.041596727713077972, 0.33501214811673785)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 323, 27, 11, 0.041608821711498184, 0.33377197229334338)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 324, 27, 12, 0.0416209157099184, 0.332535731598767)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 325, 28, 1, 0.041633009708338616, 0.33130344335241907)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 326, 28, 2, 0.041645103706758835, 0.33007508411385356)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 327, 28, 3, 0.041657197705179054, 0.32885063064157982)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 328, 28, 4, 0.041669291703599266, 0.32763010001778847)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 329, 28, 5, 0.041681385702019486, 0.32641346898213192)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 330, 28, 6, 0.041693479700439705, 0.32520071447171839)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 331, 28, 7, 0.041705573698859917, 0.32399185333411989)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 332, 28, 8, 0.041717667697280136, 0.32278686248812971)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 333, 28, 9, 0.041729761695700342, 0.32158571904851452)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 334, 28, 10, 0.041741855694120561, 0.32038843963079666)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 335, 28, 11, 0.041753949692540787, 0.3191950013319651)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 336, 28, 12, 0.041766043690961006, 0.31800538144349938)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 337, 29, 1, 0.041778137689381219, 0.316819596351425)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 338, 29, 2, 0.041790231687801431, 0.31563762332998213)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 339, 29, 3, 0.041802325686221643, 0.314459439846415)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 340, 29, 4, 0.041814419684641869, 0.31328506205979023)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 341, 29, 5, 0.041826513683062082, 0.31211446742064447)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 342, 29, 6, 0.041838607681482308, 0.31094763357105082)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 343, 29, 7, 0.041850701679902513, 0.30978457644562879)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 344, 29, 8, 0.04186279567832274, 0.308625273670262)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 345, 29, 9, 0.041874889676742945, 0.30746970306091703)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 346, 29, 10, 0.041886983675163164, 0.30631788033025492)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 347, 29, 11, 0.04189907767358339, 0.30516978327856259)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 348, 29, 12, 0.04191117167200361, 0.30402538989475542)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 349, 30, 1, 0.041923265670423815, 0.3028847156720148)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 350, 30, 2, 0.041935359668844013, 0.30174773858408355)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 351, 30, 3, 0.041947453667264233, 0.30061443679188721)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 352, 30, 4, 0.041959547665684438, 0.29948482557158135)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 353, 30, 5, 0.041971641664104643, 0.29835888306941982)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 354, 30, 6, 0.041983735662524856, 0.297236587617401)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 355, 30, 7, 0.041995829660945061, 0.29611795427708837)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 356, 30, 8, 0.042007923659365266, 0.29500296136630327)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 357, 30, 9, 0.042020017657785479, 0.29389158738718074)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 358, 30, 10, 0.042032111656205684, 0.29278384718910594)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 359, 30, 11, 0.042044205654625889, 0.29167971926052527)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 360, 30, 12, 0.0420562996530461, 0.29057918227277563)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 361, 31, 1, 0.0420562996530461, 0.28958333893738608)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 362, 31, 2, 0.0420562996530461, 0.288590908454703)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 363, 31, 3, 0.0420562996530461, 0.28760186728050674)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 364, 31, 4, 0.0420562996530461, 0.28661622749538268)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 365, 31, 5, 0.0420562996530461, 0.28563396559439824)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 366, 31, 6, 0.0420562996530461, 0.28465505827457133)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 367, 31, 7, 0.0420562996530461, 0.28367951749270781)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 368, 31, 8, 0.0420562996530461, 0.28270731998471005)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 369, 31, 9, 0.0420562996530461, 0.2817384426863615)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 370, 31, 10, 0.0420562996530461, 0.28077289743195694)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 371, 31, 11, 0.0420562996530461, 0.27981066119576592)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 372, 31, 12, 0.0420562996530461, 0.27885171114989116)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 373, 32, 1, 0.0420562996530461, 0.27789605900737152)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 374, 32, 2, 0.0420562996530461, 0.27694368197840147)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 375, 32, 3, 0.0420562996530461, 0.27599455746898144)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 376, 32, 4, 0.0420562996530461, 0.27504869707213697)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 377, 32, 5, 0.0420562996530461, 0.27410607823157007)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 378, 32, 6, 0.0420562996530461, 0.27316667858478239)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 379, 32, 7, 0.0420562996530461, 0.2722305096060158)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 380, 32, 8, 0.0420562996530461, 0.27129754897008712)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 381, 32, 9, 0.0420562996530461, 0.27036777454362748)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 382, 32, 10, 0.0420562996530461, 0.26944119768331193)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 383, 32, 11, 0.0420562996530461, 0.26851779629270439)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 384, 32, 12, 0.0420562996530461, 0.26759754846521744)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 385, 33, 1, 0.0420562996530461, 0.26668046544116408)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 386, 33, 2, 0.0420562996530461, 0.26576652535051148)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 387, 33, 3, 0.0420562996530461, 0.26485570651113011)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 388, 33, 4, 0.0420562996530461, 0.2639480200481632)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 389, 33, 5, 0.0420562996530461, 0.26304344431566129)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 390, 33, 6, 0.0420562996530461, 0.262141957853653)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 391, 33, 7, 0.0420562996530461, 0.26124357167329176)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 392, 33, 8, 0.0420562996530461, 0.26034826435041558)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 393, 33, 9, 0.0420562996530461, 0.259456014644935)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 394, 33, 10, 0.0420562996530461, 0.25856683345518156)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 395, 33, 11, 0.0420562996530461, 0.25768069957650824)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 396, 33, 12, 0.0420562996530461, 0.25679759198645447)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 397, 34, 1, 0.0420562996530461, 0.255917521471686)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 398, 34, 2, 0.0420562996530461, 0.25504046704482164)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 399, 34, 3, 0.0420562996530461, 0.25416640789879991)
GO
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 400, 34, 4, 0.0420562996530461, 0.25329535470976478)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 401, 34, 5, 0.0420562996530461, 0.25242728670537468)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 402, 34, 6, 0.0420562996530461, 0.25156218329176022)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 403, 34, 7, 0.0420562996530461, 0.25070005503567622)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 404, 34, 8, 0.0420562996530461, 0.2498408813776174)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 405, 34, 9, 0.0420562996530461, 0.24898464193472197)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 406, 34, 10, 0.0420562996530461, 0.2481313471654763)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 407, 34, 11, 0.0420562996530461, 0.24728097672103067)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 408, 34, 12, 0.0420562996530461, 0.246433510427369)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 409, 35, 1, 0.0420562996530461, 0.24558895863581851)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 410, 35, 2, 0.0420562996530461, 0.24474730120602667)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 411, 35, 3, 0.0420562996530461, 0.24390851817068321)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 412, 35, 4, 0.0420562996530461, 0.24307261977505415)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 413, 35, 5, 0.0420562996530461, 0.24223958608514784)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 414, 35, 6, 0.0420562996530461, 0.2414093973382419)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 415, 35, 7, 0.0420562996530461, 0.24058206367462789)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 416, 35, 8, 0.0420562996530461, 0.23975756536456067)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 417, 35, 9, 0.0420562996530461, 0.23893588284780939)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 418, 35, 10, 0.0420562996530461, 0.23811702616076688)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 419, 35, 11, 0.0420562996530461, 0.23730097577584164)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 420, 35, 12, 0.0420562996530461, 0.23648771233321977)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 421, 36, 1, 0.0420562996530461, 0.23567724576645971)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 422, 36, 2, 0.0420562996530461, 0.23486955674805249)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 423, 36, 3, 0.0420562996530461, 0.23406462611654749)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 424, 36, 4, 0.0420562996530461, 0.23326246370372261)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 425, 36, 5, 0.0420562996530461, 0.23246305038010118)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 426, 36, 6, 0.0420562996530461, 0.23166636718056352)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 427, 36, 7, 0.0420562996530461, 0.23087242383614973)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 428, 36, 8, 0.0420562996530461, 0.23008120141338645)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 429, 36, 9, 0.0420562996530461, 0.22929268114147328)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 430, 36, 10, 0.0420562996530461, 0.22850687265174469)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 431, 36, 11, 0.0420562996530461, 0.22772375720472235)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 432, 36, 12, 0.0420562996530461, 0.22694331622193412)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 433, 37, 1, 0.0420562996530461, 0.22616555923603049)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 434, 37, 2, 0.0420562996530461, 0.22539046769954041)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 435, 37, 3, 0.0420562996530461, 0.2246180232243494)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 436, 37, 4, 0.0420562996530461, 0.22384823524543507)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 437, 37, 5, 0.0420562996530461, 0.22308108540536634)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 438, 37, 6, 0.0420562996530461, 0.22231655550443594)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 439, 37, 7, 0.0420562996530461, 0.22155465488094933)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 440, 37, 8, 0.0420562996530461, 0.22079536536556832)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 441, 37, 9, 0.0420562996530461, 0.22003866894506233)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 442, 37, 10, 0.0420562996530461, 0.21928457486205527)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 443, 37, 11, 0.0420562996530461, 0.21853306513337453)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 444, 37, 12, 0.0420562996530461, 0.21778412193035557)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 445, 38, 1, 0.0420562996530461, 0.21703775440092113)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 446, 38, 2, 0.0420562996530461, 0.21629394474615668)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 447, 38, 3, 0.0420562996530461, 0.21555267532007269)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 448, 38, 4, 0.0420562996530461, 0.214813955176861)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 449, 38, 5, 0.0420562996530461, 0.21407776669997722)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 450, 38, 6, 0.0420562996530461, 0.21334409242423516)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 451, 38, 7, 0.0420562996530461, 0.21261294131105607)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 452, 38, 8, 0.0420562996530461, 0.2118842959243972)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 453, 38, 9, 0.0420562996530461, 0.21115813897802305)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 454, 38, 10, 0.0420562996530461, 0.21043447934153495)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 455, 38, 11, 0.0420562996530461, 0.20971329975754227)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 456, 38, 12, 0.0420562996530461, 0.20899458311692667)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 457, 39, 1, 0.0420562996530461, 0.20827833819841032)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 458, 39, 2, 0.0420562996530461, 0.20756454792142423)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 459, 39, 3, 0.0420562996530461, 0.20685319535215249)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 460, 39, 4, 0.0420562996530461, 0.20614428917936928)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 461, 39, 5, 0.0420562996530461, 0.20543781249751544)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 462, 39, 6, 0.0420562996530461, 0.20473374854628137)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 463, 39, 7, 0.0420562996530461, 0.20403210592541479)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 464, 39, 8, 0.0420562996530461, 0.20333286790257335)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 465, 39, 9, 0.0420562996530461, 0.20263601788917587)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 466, 39, 10, 0.0420562996530461, 0.2019415643968559)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 467, 39, 11, 0.0420562996530461, 0.20124949086471294)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 468, 39, 12, 0.0420562996530461, 0.20055978087413481)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 469, 40, 1, 0.0420562996530461, 0.19987244284954361)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 470, 40, 2, 0.0420562996530461, 0.19918746039972418)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 471, 40, 3, 0.0420562996530461, 0.19850481727429176)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 472, 40, 4, 0.0420562996530461, 0.19782452181135057)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 473, 40, 5, 0.0420562996530461, 0.19714655778763221)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 474, 40, 6, 0.0420562996530461, 0.19647090911925558)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 475, 40, 7, 0.0420562996530461, 0.19579758405889158)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 476, 40, 8, 0.0420562996530461, 0.19512656654949764)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 477, 40, 9, 0.0420562996530461, 0.19445784067199037)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 478, 40, 10, 0.0420562996530461, 0.19379141459448265)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 479, 40, 11, 0.0420562996530461, 0.19312727242445463)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 480, 40, 12, 0.0420562996530461, 0.19246539840593205)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 481, 41, 1, 0.0420562996530461, 0.19180580062333619)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 482, 41, 2, 0.0420562996530461, 0.19114846334698413)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 483, 41, 3, 0.0420562996530461, 0.19049337098233959)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 484, 41, 4, 0.0420562996530461, 0.18984053153098973)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 485, 41, 5, 0.0420562996530461, 0.18918992942442017)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 486, 41, 6, 0.0420562996530461, 0.18854154922787839)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 487, 41, 7, 0.0420562996530461, 0.18789539886096618)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 488, 41, 8, 0.0420562996530461, 0.18725146291468636)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 489, 41, 9, 0.0420562996530461, 0.18660972611243304)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 490, 41, 10, 0.0420562996530461, 0.18597019629266265)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 491, 41, 11, 0.0420562996530461, 0.18533285820426074)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 492, 41, 12, 0.0420562996530461, 0.1846976967271477)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 493, 42, 1, 0.0420562996530461, 0.18406471961946602)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 494, 42, 2, 0.0420562996530461, 0.18343391178636631)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 495, 42, 3, 0.0420562996530461, 0.1828052582626914)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 496, 42, 4, 0.0420562996530461, 0.18217876672709277)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 497, 42, 5, 0.0420562996530461, 0.18155442223938495)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 498, 42, 6, 0.0420562996530461, 0.1809322099877459)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 499, 42, 7, 0.0420562996530461, 0.18031213757215056)
GO
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 500, 42, 8, 0.0420562996530461, 0.17969419020549271)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 501, 42, 9, 0.0420562996530461, 0.17907835322771426)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 502, 42, 10, 0.0420562996530461, 0.17846463416091976)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 503, 42, 11, 0.0420562996530461, 0.17785301836951378)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 504, 42, 12, 0.0420562996530461, 0.1772434913436472)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 505, 43, 1, 0.0420562996530461, 0.17663606052835207)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 506, 43, 2, 0.0420562996530461, 0.17603071143799126)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 507, 43, 3, 0.0420562996530461, 0.1754274297113857)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 508, 43, 4, 0.0420562996530461, 0.17482622271728449)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 509, 43, 5, 0.0420562996530461, 0.17422707611847241)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 510, 43, 6, 0.0420562996530461, 0.17362997570091704)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 511, 43, 7, 0.0420562996530461, 0.17303492875786627)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 512, 43, 8, 0.0420562996530461, 0.172441921099006)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 513, 43, 9, 0.0420562996530461, 0.1718509386559427)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 514, 43, 10, 0.0420562996530461, 0.17126198864719669)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 515, 43, 11, 0.0420562996530461, 0.1706750570278498)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 516, 43, 12, 0.0420562996530461, 0.17009012987365524)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 517, 44, 1, 0.0420562996530461, 0.16950721432917135)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 518, 44, 2, 0.0420562996530461, 0.16892629649338611)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 519, 44, 3, 0.0420562996530461, 0.1683473625847226)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 520, 44, 4, 0.0420562996530461, 0.16777041967453496)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 521, 44, 5, 0.0420562996530461, 0.16719545400424291)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 522, 44, 6, 0.0420562996530461, 0.16662245193347747)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 523, 44, 7, 0.0420562996530461, 0.16605142046113869)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 524, 44, 8, 0.0420562996530461, 0.16548234596961867)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 525, 44, 9, 0.0420562996530461, 0.16491521495830955)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 526, 44, 10, 0.0420562996530461, 0.16435003435439965)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 527, 44, 11, 0.0420562996530461, 0.16378679067980903)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 528, 44, 12, 0.0420562996530461, 0.16322547057225889)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 529, 45, 1, 0.0420562996530461, 0.16266608088796064)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 530, 45, 2, 0.0420562996530461, 0.16210860828693263)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 531, 45, 3, 0.0420562996530461, 0.16155303954380781)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 532, 45, 4, 0.0420562996530461, 0.16099938144454798)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 533, 45, 5, 0.0420562996530461, 0.1604476207858547)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 534, 45, 6, 0.0420562996530461, 0.15989774447786997)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 535, 45, 7, 0.0420562996530461, 0.1593497592370256)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 536, 45, 8, 0.0420562996530461, 0.15880365199530605)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 537, 45, 9, 0.0420562996530461, 0.15825940979697381)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 538, 45, 10, 0.0420562996530461, 0.1577170392896432)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 539, 45, 11, 0.0420562996530461, 0.15717652753919539)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 540, 45, 12, 0.0420562996530461, 0.15663786172263919)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 541, 46, 1, 0.0420562996530461, 0.1561010484194765)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 542, 46, 2, 0.0420562996530461, 0.1555660748281133)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 543, 46, 3, 0.0420562996530461, 0.15503292825694456)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 544, 46, 4, 0.0420562996530461, 0.15450161521805772)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 545, 46, 5, 0.0420562996530461, 0.15397212304102567)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 546, 46, 6, 0.0420562996530461, 0.15344443916428327)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 547, 46, 7, 0.0420562996530461, 0.15291857003319428)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 548, 46, 8, 0.0420562996530461, 0.15239450310715449)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 549, 46, 9, 0.0420562996530461, 0.15187222595330643)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 550, 46, 10, 0.0420562996530461, 0.15135174495097364)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 551, 46, 11, 0.0420562996530461, 0.15083304768804479)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 552, 46, 12, 0.0420562996530461, 0.15031612185905113)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 553, 47, 1, 0.0420562996530461, 0.14980097377795282)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 554, 47, 2, 0.0420562996530461, 0.14928759115981471)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 555, 47, 3, 0.0420562996530461, 0.14877596182525166)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 556, 47, 4, 0.0420562996530461, 0.14826609202353006)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 557, 47, 5, 0.0420562996530461, 0.14775796959558796)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 558, 47, 6, 0.0420562996530461, 0.14725158248683185)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 559, 47, 7, 0.0420562996530461, 0.14674693688249735)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 560, 47, 8, 0.0420562996530461, 0.14624402074810589)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 561, 47, 9, 0.0420562996530461, 0.14574282215257706)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 562, 47, 10, 0.0420562996530461, 0.14524334721777163)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 563, 47, 11, 0.0420562996530461, 0.14474558403251805)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 564, 47, 12, 0.0420562996530461, 0.14424952078798342)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 565, 48, 1, 0.0420562996530461, 0.14375516354330303)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 566, 48, 2, 0.0420562996530461, 0.14326250050934888)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 567, 48, 3, 0.0420562996530461, 0.14277151999828303)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 568, 48, 4, 0.0420562996530461, 0.142282228007158)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 569, 48, 5, 0.0420562996530461, 0.14179461286763886)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 570, 48, 6, 0.0420562996530461, 0.14130866301164291)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 571, 48, 7, 0.0420562996530461, 0.140824384374776)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 572, 48, 8, 0.0420562996530461, 0.14034176540825866)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 573, 48, 9, 0.0420562996530461, 0.13986079466253629)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 574, 48, 10, 0.0420562996530461, 0.13938147801239778)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 575, 48, 11, 0.0420562996530461, 0.138903804027394)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 576, 48, 12, 0.0420562996530461, 0.13842776137528412)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 577, 49, 1, 0.0420562996530461, 0.13795335587066313)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 578, 49, 2, 0.0420562996530461, 0.13748057620019985)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 579, 49, 3, 0.0420562996530461, 0.13700941114776521)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 580, 49, 4, 0.0420562996530461, 0.13653986646837704)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 581, 49, 5, 0.0420562996530461, 0.13607193096462214)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 582, 49, 6, 0.0420562996530461, 0.13560559353529345)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 583, 49, 7, 0.0420562996530461, 0.13514085987644206)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 584, 49, 8, 0.0420562996530461, 0.1346777189053851)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 585, 49, 9, 0.0420562996530461, 0.13421615963465997)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 586, 49, 10, 0.0420562996530461, 0.1337561877019553)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 587, 49, 11, 0.0420562996530461, 0.13329779213814283)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 588, 49, 12, 0.0420562996530461, 0.13284096206833912)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 589, 50, 1, 0.0420562996530461, 0.13238570307246822)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 590, 50, 2, 0.0420562996530461, 0.13193200429379312)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 591, 50, 3, 0.0420562996530461, 0.13147985496885598)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 592, 50, 4, 0.0420562996530461, 0.1310292606204081)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 593, 50, 5, 0.0420562996530461, 0.13058021050295215)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 594, 50, 6, 0.0420562996530461, 0.13013269396331417)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 595, 50, 7, 0.0420562996530461, 0.12968671646765861)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 596, 50, 8, 0.0420562996530461, 0.129242267380588)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 597, 50, 9, 0.0420562996530461, 0.12879933615808226)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 598, 50, 10, 0.0420562996530461, 0.12835792821029879)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 599, 50, 11, 0.0420562996530461, 0.12791803301081189)
GO
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 600, 50, 12, 0.0420562996530461, 0.127479640123637)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 601, 51, 1, 0.0420562996530461, 0.12704275490349823)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 602, 51, 2, 0.0420562996530461, 0.12660736693182514)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 603, 51, 3, 0.0420562996530461, 0.12617346587956174)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 604, 51, 4, 0.0420562996530461, 0.12574105704656693)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 605, 51, 5, 0.0420562996530461, 0.12531013012102032)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 606, 51, 6, 0.0420562996530461, 0.12488067487969894)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 607, 51, 7, 0.0420562996530461, 0.12445269656815851)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 608, 51, 8, 0.0420562996530461, 0.1240261849802351)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 609, 51, 9, 0.0420562996530461, 0.12360112999745423)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 610, 51, 10, 0.0420562996530461, 0.12317753681162498)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 611, 51, 11, 0.0420562996530461, 0.12275539532115717)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 612, 51, 12, 0.0420562996530461, 0.12233469551125165)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 613, 52, 1, 0.0420562996530461, 0.12191544252052146)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 614, 52, 2, 0.0420562996530461, 0.12149762635087877)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 615, 52, 3, 0.0420562996530461, 0.12108123709013742)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 616, 52, 4, 0.0420562996530461, 0.12066627982425957)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 617, 52, 5, 0.0420562996530461, 0.12025274465759911)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 618, 52, 6, 0.0420562996530461, 0.1198406217795316)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 619, 52, 7, 0.0420562996530461, 0.11942991622390767)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 620, 52, 8, 0.0420562996530461, 0.11902061819647343)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 621, 52, 9, 0.0420562996530461, 0.11861271798712544)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 622, 52, 10, 0.0420562996530461, 0.1182062205781368)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 623, 52, 11, 0.0420562996530461, 0.11780111627560694)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 624, 52, 12, 0.0420562996530461, 0.11739739546892344)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 625, 53, 1, 0.0420562996530461, 0.1169950630893104)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 626, 53, 2, 0.0420562996530461, 0.11659410954219225)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 627, 53, 3, 0.0420562996530461, 0.11619452531542833)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 628, 53, 4, 0.0420562996530461, 0.11579631528971664)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 629, 53, 5, 0.0420562996530461, 0.11539946996878903)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 630, 53, 6, 0.0420562996530461, 0.11500397993796754)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 631, 53, 7, 0.0420562996530461, 0.11460985002794188)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 632, 53, 8, 0.0420562996530461, 0.11421707083974397)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 633, 53, 9, 0.0420562996530461, 0.11382563305515997)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 634, 53, 10, 0.0420562996530461, 0.11343554145538366)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 635, 53, 11, 0.0420562996530461, 0.11304678673775012)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 636, 53, 12, 0.0420562996530461, 0.11265935967952122)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 637, 54, 1, 0.0420562996530461, 0.11227326501290195)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 638, 54, 2, 0.0420562996530461, 0.11188849353054381)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 639, 54, 3, 0.0420562996530461, 0.11150503610420612)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 640, 54, 4, 0.0420562996530461, 0.11112289741760706)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 641, 54, 5, 0.0420562996530461, 0.11074206835773791)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 642, 54, 6, 0.0420562996530461, 0.1103625398898872)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 643, 54, 7, 0.0420562996530461, 0.1099843166497831)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 644, 54, 8, 0.0420562996530461, 0.10960738961779003)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 645, 54, 9, 0.0420562996530461, 0.10923174985176748)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 646, 54, 10, 0.0420562996530461, 0.10885740193994525)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 647, 54, 11, 0.0420562996530461, 0.10848433695510425)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 648, 54, 12, 0.0420562996530461, 0.10811254604672635)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 649, 55, 1, 0.0420562996530461, 0.10774203375602977)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 650, 55, 2, 0.0420562996530461, 0.10737279124726487)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 651, 55, 3, 0.0420562996530461, 0.10700480976059726)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 652, 55, 4, 0.0420562996530461, 0.10663809379071512)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 653, 55, 5, 0.0420562996530461, 0.10627263459240122)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 654, 55, 6, 0.0420562996530461, 0.10590842349557557)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 655, 55, 7, 0.0420562996530461, 0.10554546494887322)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 656, 55, 8, 0.0420562996530461, 0.10518375029668162)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 657, 55, 9, 0.0420562996530461, 0.10482327095775566)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 658, 55, 10, 0.0420562996530461, 0.10446403133514903)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 659, 55, 11, 0.0420562996530461, 0.10410602286193581)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 660, 55, 12, 0.0420562996530461, 0.10374923704479552)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 661, 56, 1, 0.0420562996530461, 0.10339367824166756)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 662, 56, 2, 0.0420562996530461, 0.10303933797340392)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 663, 56, 3, 0.0420562996530461, 0.10268620783370787)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 664, 56, 4, 0.0420562996530461, 0.10233429213586676)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 665, 56, 5, 0.0420562996530461, 0.10198358248761111)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 666, 56, 6, 0.0420562996530461, 0.1016340705687763)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 667, 56, 7, 0.0420562996530461, 0.1012857606484551)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 668, 56, 8, 0.0420562996530461, 0.10093864442036643)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 669, 56, 9, 0.0420562996530461, 0.10059271364959524)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 670, 56, 10, 0.0420562996530461, 0.10024797256149257)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 671, 56, 11, 0.0420562996530461, 0.099904412934884654)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 672, 56, 12, 0.0420562996530461, 0.099562026619232538)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 673, 57, 1, 0.0420562996530461, 0.099220817796593738)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 674, 57, 2, 0.0420562996530461, 0.09888077833002977)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 675, 57, 3, 0.0420562996530461, 0.09854190015251324)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 676, 57, 4, 0.0420562996530461, 0.098204187403251722)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 677, 57, 5, 0.0420562996530461, 0.09786763202867893)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 678, 57, 6, 0.0420562996530461, 0.0975322260444234)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 679, 57, 7, 0.0420562996530461, 0.097197973547281782)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 680, 57, 8, 0.0420562996530461, 0.096864866566205757)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 681, 57, 9, 0.0420562996530461, 0.096532897198632839)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 682, 57, 10, 0.0420562996530461, 0.096202069499383341)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 683, 57, 11, 0.0420562996530461, 0.095872375579081431)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 684, 57, 12, 0.0420562996530461, 0.095543807616135373)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 685, 58, 1, 0.0420562996530461, 0.095216369623819214)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 686, 58, 2, 0.0420562996530461, 0.094890053793592763)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 687, 58, 3, 0.0420562996530461, 0.094564852384005443)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 688, 58, 4, 0.0420562996530461, 0.094240769367210708)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 689, 58, 5, 0.0420562996530461, 0.093917797014675786)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 690, 58, 6, 0.0420562996530461, 0.093595927664270037)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 691, 58, 7, 0.0420562996530461, 0.093275165247447736)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 692, 58, 8, 0.0420562996530461, 0.0929555021148637)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 693, 58, 9, 0.0420562996530461, 0.09263693068289458)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 694, 58, 10, 0.0420562996530461, 0.092319454842712381)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 695, 58, 11, 0.0420562996530461, 0.09200306702334822)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 696, 58, 12, 0.0420562996530461, 0.0916877597188816)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 697, 59, 1, 0.0420562996530461, 0.091373536780615036)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 698, 59, 2, 0.0420562996530461, 0.091060390715152845)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 699, 59, 3, 0.0420562996530461, 0.090748314093481247)
GO
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 700, 59, 4, 0.0420562996530461, 0.09043731072744178)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 701, 59, 5, 0.0420562996530461, 0.090127373200417124)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 702, 59, 6, 0.0420562996530461, 0.089818494159512222)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 703, 59, 7, 0.0420562996530461, 0.089510677377511963)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 704, 59, 8, 0.0420562996530461, 0.089203915513790713)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 705, 59, 9, 0.0420562996530461, 0.08889820129079222)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 706, 59, 10, 0.0420562996530461, 0.088593538442644865)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 707, 59, 11, 0.0420562996530461, 0.088289919703936112)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 708, 59, 12, 0.0420562996530461, 0.087987337871676563)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 709, 60, 1, 0.0420562996530461, 0.0876857966417342)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 710, 60, 2, 0.0420562996530461, 0.087385288823138951)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 711, 60, 3, 0.0420562996530461, 0.0870858072867042)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 712, 60, 4, 0.0420562996530461, 0.086787355690429585)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 713, 60, 5, 0.0420562996530461, 0.086489926917024687)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 714, 60, 6, 0.0420562996530461, 0.086193513910349573)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 715, 60, 7, 0.0420562996530461, 0.085898120290923488)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 716, 60, 8, 0.0420562996530461, 0.085603739014380772)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 717, 60, 9, 0.0420562996530461, 0.085310363096879685)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 718, 60, 10, 0.0420562996530461, 0.085017996121843117)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 719, 60, 11, 0.0420562996530461, 0.084726631117082979)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 720, 60, 12, 0.0420562996530461, 0.084436261170314941)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 721, 61, 1, 0.0420562996530461, 0.084146889828245655)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 722, 61, 2, 0.0420562996530461, 0.083858510190125038)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 723, 61, 3, 0.0420562996530461, 0.083571115414492983)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 724, 61, 4, 0.0420562996530461, 0.083284709011716113)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 725, 61, 5, 0.0420562996530461, 0.082999284151750355)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 726, 61, 6, 0.0420562996530461, 0.082714834063234224)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 727, 61, 7, 0.0420562996530461, 0.082431362220566559)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 728, 61, 8, 0.0420562996530461, 0.082148861863684947)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 729, 61, 9, 0.0420562996530461, 0.081867326290608181)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 730, 61, 10, 0.0420562996530461, 0.081586758940135937)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 731, 61, 11, 0.0420562996530461, 0.081307153121470327)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 732, 61, 12, 0.0420562996530461, 0.08102850220129959)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 733, 62, 1, 0.0420562996530461, 0.080750809583189)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 734, 62, 2, 0.0420562996530461, 0.080474068644895508)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 735, 62, 3, 0.0420562996530461, 0.0801982728210732)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 736, 62, 4, 0.0420562996530461, 0.079923425480413923)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 737, 62, 5, 0.0420562996530461, 0.079649520068527074)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 738, 62, 6, 0.0420562996530461, 0.0793765500873362)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 739, 62, 7, 0.0420562996530461, 0.079104518871017035)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 740, 62, 8, 0.0420562996530461, 0.07883341993233621)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 741, 62, 9, 0.0420562996530461, 0.078563246839797429)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 742, 62, 10, 0.0420562996530461, 0.078294002893414052)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 743, 62, 11, 0.0420562996530461, 0.078025681672421771)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 744, 62, 12, 0.0420562996530461, 0.077758276811222327)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 745, 63, 1, 0.0420562996530461, 0.077491791576016655)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 746, 63, 2, 0.0420562996530461, 0.077226219611828517)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 747, 63, 3, 0.0420562996530461, 0.076961554618282441)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 748, 63, 4, 0.0420562996530461, 0.07669779982811345)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 749, 63, 5, 0.0420562996530461, 0.076434948951459233)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 750, 63, 6, 0.0420562996530461, 0.07617299575249889)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 751, 63, 7, 0.0420562996530461, 0.07591194343084437)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 752, 63, 8, 0.0420562996530461, 0.075651785761080184)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 753, 63, 9, 0.0420562996530461, 0.0753925165712785)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 754, 63, 10, 0.0420562996530461, 0.075134139028267613)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 755, 63, 11, 0.0420562996530461, 0.074876646970418514)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 756, 63, 12, 0.0420562996530461, 0.07462003428904182)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 757, 64, 1, 0.0420562996530461, 0.074364304118518021)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 758, 64, 2, 0.0420562996530461, 0.074109450360351048)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 759, 64, 3, 0.0420562996530461, 0.073855466968442)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 760, 64, 4, 0.0420562996530461, 0.073602357045056077)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 761, 64, 5, 0.0420562996530461, 0.073350114554183249)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 762, 64, 6, 0.0420562996530461, 0.073098733511673786)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 763, 64, 7, 0.0420562996530461, 0.072848216988006642)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 764, 64, 8, 0.0420562996530461, 0.072598559009017585)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 765, 64, 9, 0.0420562996530461, 0.072349753651871337)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 766, 64, 10, 0.0420562996530461, 0.0721018039555863)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 767, 64, 11, 0.0420562996530461, 0.071854704007210349)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 768, 64, 12, 0.0420562996530461, 0.071608447944594408)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 769, 65, 1, 0.0420562996530461, 0.071363038775618684)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 770, 65, 2, 0.0420562996530461, 0.071118470647915918)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 771, 65, 3, 0.0420562996530461, 0.070874737759401549)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 772, 65, 4, 0.0420562996530461, 0.070631843087136562)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 773, 65, 5, 0.0420562996530461, 0.070389780838717872)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 774, 65, 6, 0.0420562996530461, 0.0701485452715099)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 775, 65, 7, 0.0420562996530461, 0.069908139332070227)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 776, 65, 8, 0.0420562996530461, 0.069668557287345556)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 777, 65, 9, 0.0420562996530461, 0.069429793453540167)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 778, 65, 10, 0.0420562996530461, 0.069191850747020778)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 779, 65, 11, 0.0420562996530461, 0.068954723493475784)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 780, 65, 12, 0.0420562996530461, 0.068718406067346388)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 781, 66, 1, 0.0420562996530461, 0.068482901355117851)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 782, 66, 2, 0.0420562996530461, 0.068248203740618338)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 783, 66, 3, 0.0420562996530461, 0.068014307655929335)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 784, 66, 4, 0.0420562996530461, 0.067781215957960744)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 785, 66, 5, 0.0420562996530461, 0.067548923088084814)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 786, 66, 6, 0.0420562996530461, 0.067317423535432727)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 787, 66, 7, 0.0420562996530461, 0.06708672012764208)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 788, 66, 8, 0.0420562996530461, 0.066856807363039589)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 789, 66, 9, 0.0420562996530461, 0.066627679787221575)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 790, 66, 10, 0.0420562996530461, 0.066399340198853254)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 791, 66, 11, 0.0420562996530461, 0.0661717831526323)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 792, 66, 12, 0.0420562996530461, 0.065945003250041545)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 793, 67, 1, 0.0420562996530461, 0.065719003261070746)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 794, 67, 2, 0.0420562996530461, 0.065493777796210878)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 795, 67, 3, 0.0420562996530461, 0.065269321512258768)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 796, 67, 4, 0.0420562996530461, 0.065045637150822441)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 797, 67, 5, 0.0420562996530461, 0.064822719377614552)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 798, 67, 6, 0.0420562996530461, 0.064600562904179121)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 799, 67, 7, 0.0420562996530461, 0.064379170444033282)
GO
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 800, 67, 8, 0.0420562996530461, 0.064158536717545539)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 801, 67, 9, 0.0420562996530461, 0.0639386564904462)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 802, 67, 10, 0.0420562996530461, 0.063719532448449287)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 803, 67, 11, 0.0420562996530461, 0.063501159366019161)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 804, 67, 12, 0.0420562996530461, 0.063283532062517175)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 805, 68, 1, 0.0420562996530461, 0.063066653196139189)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 806, 68, 2, 0.0420562996530461, 0.0628505175948911)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 807, 68, 3, 0.0420562996530461, 0.062635120131215818)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 808, 68, 4, 0.0420562996530461, 0.062420463436072958)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 809, 68, 5, 0.0420562996530461, 0.062206542390461396)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 810, 68, 6, 0.0420562996530461, 0.061993351919361707)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 811, 68, 7, 0.0420562996530461, 0.061780894626776321)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 812, 68, 8, 0.0420562996530461, 0.061569165446154116)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 813, 68, 9, 0.0420562996530461, 0.061358159354475042)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 814, 68, 10, 0.0420562996530461, 0.06114787892906054)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 815, 68, 11, 0.0420562996530461, 0.060938319155272085)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 816, 68, 12, 0.0420562996530461, 0.060729475061556189)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 817, 69, 1, 0.0420562996530461, 0.060521349198826693)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 818, 69, 2, 0.0420562996530461, 0.06031393660382578)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 819, 69, 3, 0.0420562996530461, 0.060107232355939184)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 820, 69, 4, 0.0420562996530461, 0.059901238979943726)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 821, 69, 5, 0.0420562996530461, 0.059695951563435816)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 822, 69, 6, 0.0420562996530461, 0.0594913652362185)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 823, 69, 7, 0.0420562996530461, 0.059287482497199381)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 824, 69, 8, 0.0420562996530461, 0.059084298484308045)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 825, 69, 9, 0.0420562996530461, 0.058881808377248254)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 826, 69, 10, 0.0420562996530461, 0.058680014649323459)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 827, 69, 11, 0.0420562996530461, 0.058478912488280695)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 828, 69, 12, 0.0420562996530461, 0.058278497123213154)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 829, 70, 1, 0.0420562996530461, 0.058078771002082474)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 830, 70, 2, 0.0420562996530461, 0.05787972936194271)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 831, 70, 3, 0.0420562996530461, 0.057681367480770435)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 832, 70, 4, 0.0420562996530461, 0.057483687781445129)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 833, 70, 5, 0.0420562996530461, 0.057286685549822657)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 834, 70, 6, 0.0420562996530461, 0.0570903561122621)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 835, 70, 7, 0.0420562996530461, 0.056894701866817776)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 836, 70, 8, 0.0420562996530461, 0.056699718147647335)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 837, 70, 9, 0.0420562996530461, 0.056505400328996647)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 838, 70, 10, 0.0420562996530461, 0.056311750784349218)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 839, 70, 11, 0.0420562996530461, 0.056118764895669575)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 840, 70, 12, 0.0420562996530461, 0.055926438084599704)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 841, 71, 1, 0.0420562996530461, 0.055734772700304074)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 842, 71, 2, 0.0420562996530461, 0.055543764172064254)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 843, 71, 3, 0.0420562996530461, 0.055353407968432723)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 844, 71, 4, 0.0420562996530461, 0.055163706414504084)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 845, 71, 5, 0.0420562996530461, 0.054974654986392126)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 846, 71, 6, 0.0420562996530461, 0.054786249199079172)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 847, 71, 7, 0.0420562996530461, 0.054598491353836584)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 848, 71, 8, 0.0420562996530461, 0.054411376973130511)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 849, 71, 9, 0.0420562996530461, 0.054224901617897413)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 850, 71, 10, 0.0420562996530461, 0.054039067565829491)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 851, 71, 11, 0.0420562996530461, 0.053853870385270342)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 852, 71, 12, 0.0420562996530461, 0.053669305682639681)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 853, 72, 1, 0.0420562996530461, 0.053485375712292164)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 854, 72, 2, 0.0420562996530461, 0.05330207608797876)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 855, 72, 3, 0.0420562996530461, 0.053119402461136417)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 856, 72, 4, 0.0420562996530461, 0.05293735706302137)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 857, 72, 5, 0.0420562996530461, 0.052755935552326688)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 858, 72, 6, 0.0420562996530461, 0.052575133625045331)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 859, 72, 7, 0.0420562996530461, 0.052394953489571745)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 860, 72, 8, 0.0420562996530461, 0.05221539084908066)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 861, 72, 9, 0.0420562996530461, 0.052036441443664476)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 862, 72, 10, 0.0420562996530461, 0.051858107459090134)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 863, 72, 11, 0.0420562996530461, 0.051680384642558239)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 864, 72, 12, 0.0420562996530461, 0.051503268777808787)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 865, 73, 1, 0.0420562996530461, 0.051326762028213055)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 866, 73, 2, 0.0420562996530461, 0.051150860184546412)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 867, 73, 3, 0.0420562996530461, 0.050975559073749267)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 868, 73, 4, 0.0420562996530461, 0.05080086083702668)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 869, 73, 5, 0.0420562996530461, 0.05062676130828233)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 870, 73, 6, 0.0420562996530461, 0.050453256357214371)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 871, 73, 7, 0.0420562996530461, 0.050280348103088776)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 872, 73, 8, 0.0420562996530461, 0.050108032422495639)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 873, 73, 9, 0.0420562996530461, 0.049936305227452751)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 874, 73, 10, 0.0420562996530461, 0.049765168615511814)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 875, 73, 11, 0.0420562996530461, 0.049594618505511924)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 876, 73, 12, 0.0420562996530461, 0.049424650851356944)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 877, 74, 1, 0.0420562996530461, 0.049255267729106732)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 878, 74, 2, 0.0420562996530461, 0.049086465099416568)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 879, 74, 3, 0.0420562996530461, 0.048918238957647152)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 880, 74, 4, 0.0420562996530461, 0.04875059135858676)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 881, 74, 5, 0.0420562996530461, 0.048583518304278352)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 882, 74, 6, 0.0420562996530461, 0.04841701583111474)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 883, 74, 7, 0.0420562996530461, 0.048251085972830531)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 884, 74, 8, 0.0420562996530461, 0.048085724772432323)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 885, 74, 9, 0.0420562996530461, 0.0479209283069246)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 886, 74, 10, 0.0420562996530461, 0.047756698589204047)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 887, 74, 11, 0.0420562996530461, 0.047593031702821156)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 888, 74, 12, 0.0420562996530461, 0.047429923764975984)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 889, 75, 1, 0.0420562996530461, 0.047267376767940787)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 890, 75, 2, 0.0420562996530461, 0.047105386835394565)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 891, 75, 3, 0.0420562996530461, 0.046943950124321059)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 892, 75, 4, 0.0420562996530461, 0.046783068606579443)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 893, 75, 5, 0.0420562996530461, 0.046622738445566039)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 894, 75, 6, 0.0420562996530461, 0.046462955837640679)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 895, 75, 7, 0.0420562996530461, 0.046303722734458583)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 896, 75, 8, 0.0420562996530461, 0.046145035338726451)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 897, 75, 9, 0.0420562996530461, 0.04598688988577674)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 898, 75, 10, 0.0420562996530461, 0.045829288307267756)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 899, 75, 11, 0.0420562996530461, 0.045672226844813778)
GO
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 900, 75, 12, 0.0420562996530461, 0.045515701772320588)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 901, 76, 1, 0.0420562996530461, 0.045359715001654442)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 902, 76, 2, 0.0420562996530461, 0.045204262812938573)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 903, 76, 3, 0.0420562996530461, 0.04504934151825684)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 904, 76, 4, 0.0420562996530461, 0.044894953009886253)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 905, 76, 5, 0.0420562996530461, 0.044741093606064417)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 906, 76, 6, 0.0420562996530461, 0.0445877596566621)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 907, 76, 7, 0.0420562996530461, 0.044434953034567772)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 908, 76, 8, 0.0420562996530461, 0.0442826700957429)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 909, 76, 9, 0.0420562996530461, 0.044130907227457994)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 910, 76, 10, 0.0420562996530461, 0.043979666283411628)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 911, 76, 11, 0.0420562996530461, 0.043828943656902611)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 912, 76, 12, 0.0420562996530461, 0.043678735772217973)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 913, 77, 1, 0.0420562996530461, 0.043529044464063041)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 914, 77, 2, 0.0420562996530461, 0.043379866162691391)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 915, 77, 3, 0.0420562996530461, 0.043231197329027304)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 916, 77, 4, 0.0420562996530461, 0.043083039778977469)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 917, 77, 5, 0.0420562996530461, 0.042935389979371574)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 918, 77, 6, 0.0420562996530461, 0.042788244427395768)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 919, 77, 7, 0.0420562996530461, 0.042641604920350705)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 920, 77, 8, 0.0420562996530461, 0.042495467961267422)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 921, 77, 9, 0.0420562996530461, 0.042349830083222406)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 922, 77, 10, 0.0420562996530461, 0.042204693065100912)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 923, 77, 11, 0.0420562996530461, 0.042060053445764412)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 924, 77, 12, 0.0420562996530461, 0.04191590779381197)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 925, 78, 1, 0.0420562996530461, 0.04177225786990213)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 926, 78, 2, 0.0420562996530461, 0.041629100248359682)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 927, 78, 3, 0.0420562996530461, 0.041486431532942306)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 928, 78, 4, 0.0420562996530461, 0.041344253466268591)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 929, 78, 5, 0.0420562996530461, 0.041202562657763279)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 930, 78, 6, 0.0420562996530461, 0.041061355745982409)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 931, 78, 7, 0.0420562996530461, 0.040920634455689463)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 932, 78, 8, 0.0420562996530461, 0.0407803954310495)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 933, 78, 9, 0.0420562996530461, 0.040640635345060377)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 934, 78, 10, 0.0420562996530461, 0.040501355904813414)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 935, 78, 11, 0.0420562996530461, 0.040362553788858009)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 936, 78, 12, 0.0420562996530461, 0.040224225704280969)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 937, 79, 1, 0.0420562996530461, 0.040086373340682512)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 938, 79, 2, 0.0420562996530461, 0.039948993410644076)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 939, 79, 3, 0.0420562996530461, 0.039812082654992122)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 940, 79, 4, 0.0420562996530461, 0.039675642746014983)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 941, 79, 5, 0.0420562996530461, 0.039539670429977462)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 942, 79, 6, 0.0420562996530461, 0.039404162481099951)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 943, 79, 7, 0.0420562996530461, 0.039269120554536296)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 944, 79, 8, 0.0420562996530461, 0.039134541429889522)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 945, 79, 9, 0.0420562996530461, 0.039000421914431808)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 946, 79, 10, 0.0420562996530461, 0.038866763646358063)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 947, 79, 11, 0.0420562996530461, 0.038733563438267948)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 948, 79, 12, 0.0420562996530461, 0.038600818130146784)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 949, 80, 1, 0.0420562996530461, 0.038468529343404306)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 950, 80, 2, 0.0420562996530461, 0.038336693923298713)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 951, 80, 3, 0.0420562996530461, 0.0382053087421933)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 952, 80, 4, 0.0420562996530461, 0.038074375404884592)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 953, 80, 5, 0.0420562996530461, 0.037943890788954729)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 954, 80, 6, 0.0420562996530461, 0.037813851798813192)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 955, 80, 7, 0.0420562996530461, 0.037684260022813547)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 956, 80, 8, 0.0420562996530461, 0.037555112370530663)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 957, 80, 9, 0.0420562996530461, 0.037426405778091885)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 958, 80, 10, 0.0420562996530461, 0.037298141817576271)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 959, 80, 11, 0.0420562996530461, 0.037170317430223622)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 960, 80, 12, 0.0420562996530461, 0.037042929583554152)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 961, 81, 1, 0.0420562996530461, 0.036915979833539177)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 962, 81, 2, 0.0420562996530461, 0.036789465152758993)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 963, 81, 3, 0.0420562996530461, 0.036663382539805008)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 964, 81, 4, 0.0420562996530461, 0.036537733534705852)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 965, 81, 5, 0.0420562996530461, 0.036412515141061183)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 966, 81, 6, 0.0420562996530461, 0.036287724388215266)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 967, 81, 7, 0.0420562996530461, 0.036163362800417376)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 968, 81, 8, 0.0420562996530461, 0.036039427411968708)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 969, 81, 9, 0.0420562996530461, 0.035915915282651284)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 970, 81, 10, 0.0420562996530461, 0.035792827921096712)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 971, 81, 11, 0.0420562996530461, 0.035670162391993145)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 972, 81, 12, 0.0420562996530461, 0.035547915785248491)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 973, 82, 1, 0.0420562996530461, 0.035426089594036717)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 974, 82, 2, 0.0420562996530461, 0.035304680913121576)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 975, 82, 3, 0.0420562996530461, 0.0351836868622282)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 976, 82, 4, 0.0420562996530461, 0.035063108919231277)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 977, 82, 5, 0.0420562996530461, 0.034942944208662022)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 978, 82, 6, 0.0420562996530461, 0.034823189879757271)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 979, 82, 7, 0.0420562996530461, 0.0347038473952492)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 980, 82, 8, 0.0420562996530461, 0.034584913909131473)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 981, 82, 9, 0.0420562996530461, 0.034466386599850254)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 982, 82, 10, 0.0420562996530461, 0.034348266915150347)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 983, 82, 11, 0.0420562996530461, 0.034230552038186007)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 984, 82, 12, 0.0420562996530461, 0.034113239176313426)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 985, 83, 1, 0.0420562996530461, 0.033996329762443621)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 986, 83, 2, 0.0420562996530461, 0.033879821008592638)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 987, 83, 3, 0.0420562996530461, 0.033763710150730486)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 988, 83, 4, 0.0420562996530461, 0.033647998607086373)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 989, 83, 5, 0.0420562996530461, 0.03353268361824243)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 990, 83, 6, 0.0420562996530461, 0.0334177624484893)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 991, 83, 7, 0.0420562996530461, 0.033303236501524808)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 992, 83, 8, 0.0420562996530461, 0.033189103046204475)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 993, 83, 9, 0.0420562996530461, 0.0330753593748494)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 994, 83, 10, 0.0420562996530461, 0.032962006876774932)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 995, 83, 11, 0.0420562996530461, 0.032849042848820273)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 996, 83, 12, 0.0420562996530461, 0.03273646461104978)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 997, 84, 1, 0.0420562996530461, 0.032624273538543684)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 998, 84, 2, 0.0420562996530461, 0.032512466955838148)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 999, 84, 3, 0.0420562996530461, 0.032401042210456532)
GO
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1000, 84, 4, 0.0420562996530461, 0.0322900006633898)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1001, 84, 5, 0.0420562996530461, 0.032179339666587287)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1002, 84, 6, 0.0420562996530461, 0.03206905659475)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1003, 84, 7, 0.0420562996530461, 0.031959152794924)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1004, 84, 8, 0.0420562996530461, 0.031849625646190934)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1005, 84, 9, 0.0420562996530461, 0.031740472550150972)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1006, 84, 10, 0.0420562996530461, 0.031631694840048158)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1007, 84, 11, 0.0420562996530461, 0.03152328992181843)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1008, 84, 12, 0.0420562996530461, 0.031415255223685538)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1009, 85, 1, 0.0420562996530461, 0.031307592065232925)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1010, 85, 2, 0.0420562996530461, 0.031200297878975655)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1011, 85, 3, 0.0420562996530461, 0.031093370119488265)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1012, 85, 4, 0.0420562996530461, 0.030986810092833557)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1013, 85, 5, 0.0420562996530461, 0.030880615257833421)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1014, 85, 6, 0.0420562996530461, 0.030774783095143164)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1015, 85, 7, 0.0420562996530461, 0.030669314897443491)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1016, 85, 8, 0.0420562996530461, 0.030564208149593555)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1017, 85, 9, 0.0420562996530461, 0.03045946035806223)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1018, 85, 10, 0.0420562996530461, 0.030355072802285225)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1019, 85, 11, 0.0420562996530461, 0.03025104299289218)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1020, 85, 12, 0.0420562996530461, 0.030147368461901042)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1021, 86, 1, 0.0420562996530461, 0.03004405047563824)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1022, 86, 2, 0.0420562996530461, 0.029941086570239858)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1023, 86, 3, 0.0420562996530461, 0.029838474303011116)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1024, 86, 4, 0.0420562996530461, 0.029736214927303502)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1025, 86, 5, 0.0420562996530461, 0.029634306004498182)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1026, 86, 6, 0.0420562996530461, 0.029532745116928584)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1027, 86, 7, 0.0420562996530461, 0.029431533505104166)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1028, 86, 8, 0.0420562996530461, 0.02933066875539253)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1029, 86, 9, 0.0420562996530461, 0.029230148474898857)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1030, 86, 10, 0.0420562996530461, 0.029129973891422165)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1031, 86, 11, 0.0420562996530461, 0.029030142616060479)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1032, 86, 12, 0.0420562996530461, 0.028930652280436907)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1033, 87, 1, 0.0420562996530461, 0.028831504099770276)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1034, 87, 2, 0.0420562996530461, 0.028732695709635631)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1035, 87, 3, 0.0420562996530461, 0.028634224765922797)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1036, 87, 4, 0.0420562996530461, 0.028536092471399304)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1037, 87, 5, 0.0420562996530461, 0.028438296485866418)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1038, 87, 6, 0.0420562996530461, 0.02834083448923206)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1039, 87, 7, 0.0420562996530461, 0.028243707671940021)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1040, 87, 8, 0.0420562996530461, 0.028146913717769582)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1041, 87, 9, 0.0420562996530461, 0.028050450330400642)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1042, 87, 10, 0.0420562996530461, 0.027954318688079547)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1043, 87, 11, 0.0420562996530461, 0.027858516498317897)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1044, 87, 12, 0.0420562996530461, 0.027763041488324005)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1045, 88, 1, 0.0420562996530461, 0.027667894824271743)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1046, 88, 2, 0.0420562996530461, 0.027573074237161866)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1047, 88, 3, 0.0420562996530461, 0.027478577477490034)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1048, 88, 4, 0.0420562996530461, 0.027384405699481335)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1049, 88, 5, 0.0420562996530461, 0.027290556657385005)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1050, 88, 6, 0.0420562996530461, 0.027197028124745445)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1051, 88, 7, 0.0420562996530461, 0.027103821243961386)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1052, 88, 8, 0.0420562996530461, 0.027010933792292347)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1053, 88, 9, 0.0420562996530461, 0.026918363566095303)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1054, 88, 10, 0.0420562996530461, 0.026826111696063807)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1055, 88, 11, 0.0420562996530461, 0.026734175982231885)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1056, 88, 12, 0.0420562996530461, 0.02664255424353535)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1057, 89, 1, 0.0420562996530461, 0.026551247599082509)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1058, 89, 2, 0.0420562996530461, 0.026460253871448555)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1059, 89, 3, 0.0420562996530461, 0.026369570901916779)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1060, 89, 4, 0.0420562996530461, 0.026279199798128955)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1061, 89, 5, 0.0420562996530461, 0.026189138404970471)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1062, 89, 6, 0.0420562996530461, 0.026099384585843134)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1063, 89, 7, 0.0420562996530461, 0.026009939437039668)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1064, 89, 8, 0.0420562996530461, 0.025920800825527061)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1065, 89, 9, 0.0420562996530461, 0.025831966636599007)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1066, 89, 10, 0.0420562996530461, 0.02574343795531546)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1067, 89, 11, 0.0420562996530461, 0.025655212670498768)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1068, 89, 12, 0.0420562996530461, 0.025567288689110197)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1069, 90, 1, 0.0420562996530461, 0.025479667085092028)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1070, 90, 2, 0.0420562996530461, 0.025392345768898025)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1071, 90, 3, 0.0420562996530461, 0.025305322668935031)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1072, 90, 4, 0.0420562996530461, 0.025218598848141552)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1073, 90, 5, 0.0420562996530461, 0.025132172238381149)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1074, 90, 6, 0.0420562996530461, 0.025046040789286489)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1075, 90, 7, 0.0420562996530461, 0.024960205552905068)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1076, 90, 8, 0.0420562996530461, 0.024874664482290854)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1077, 90, 9, 0.0420562996530461, 0.024789415548084871)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1078, 90, 10, 0.0420562996530461, 0.024704459791555188)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1079, 90, 11, 0.0420562996530461, 0.02461979518672907)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1080, 90, 12, 0.0420562996530461, 0.024535419725040631)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1081, 91, 1, 0.0420562996530461, 0.024451334437088971)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1082, 91, 2, 0.0420562996530461, 0.024367537317659744)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1083, 91, 3, 0.0420562996530461, 0.024284026378767126)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1084, 91, 4, 0.0420562996530461, 0.024200802640450537)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1085, 91, 5, 0.0420562996530461, 0.024117864118041357)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1086, 91, 6, 0.0420562996530461, 0.024035208843922923)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1087, 91, 7, 0.0420562996530461, 0.023952837827683208)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1088, 91, 8, 0.0420562996530461, 0.023870749104988768)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1089, 91, 9, 0.0420562996530461, 0.023788940728383428)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1090, 91, 10, 0.0420562996530461, 0.023707413697110769)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1091, 91, 11, 0.0420562996530461, 0.023626166066964195)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1092, 91, 12, 0.0420562996530461, 0.023545195910441432)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1093, 92, 1, 0.0420562996530461, 0.02346450421654768)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1094, 92, 2, 0.0420562996530461, 0.02338408906099694)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1095, 92, 3, 0.0420562996530461, 0.023303948536036415)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1096, 92, 4, 0.0420562996530461, 0.0232240836205378)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1097, 92, 5, 0.0420562996530461, 0.023144492409931623)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1098, 92, 6, 0.0420562996530461, 0.023065173016012165)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1099, 92, 7, 0.0420562996530461, 0.022986126407621484)
GO
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1100, 92, 8, 0.0420562996530461, 0.022907350699704579)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1101, 92, 9, 0.0420562996530461, 0.022828844023402559)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1102, 92, 10, 0.0420562996530461, 0.022750607337630589)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1103, 92, 11, 0.0420562996530461, 0.022672638776648206)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1104, 92, 12, 0.0420562996530461, 0.022594936490745111)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1105, 93, 1, 0.0420562996530461, 0.022517501429011287)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1106, 93, 2, 0.0420562996530461, 0.022440331744822909)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1107, 93, 3, 0.0420562996530461, 0.02236342560742207)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1108, 93, 4, 0.0420562996530461, 0.022286783956174241)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1109, 93, 5, 0.0420562996530461, 0.022210404963376364)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1110, 93, 6, 0.0420562996530461, 0.022134286817028739)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1111, 93, 7, 0.0420562996530461, 0.022058430446871963)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1112, 93, 8, 0.0420562996530461, 0.02198283404392988)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1113, 93, 9, 0.0420562996530461, 0.021907495814768793)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1114, 93, 10, 0.0420562996530461, 0.021832416679603044)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1115, 93, 11, 0.0420562996530461, 0.021757594847991505)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1116, 93, 12, 0.0420562996530461, 0.021683028544876245)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1117, 94, 1, 0.0420562996530461, 0.021608718681042971)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1118, 94, 2, 0.0420562996530461, 0.021534663484395658)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1119, 94, 3, 0.0420562996530461, 0.021460861198063865)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1120, 94, 4, 0.0420562996530461, 0.021387312723501268)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1121, 94, 5, 0.0420562996530461, 0.02131401630676898)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1122, 94, 6, 0.0420562996530461, 0.021240970208997706)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1123, 94, 7, 0.0420562996530461, 0.021168175322404698)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1124, 94, 8, 0.0420562996530461, 0.021095629911022172)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1125, 94, 9, 0.0420562996530461, 0.021023332253797534)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1126, 94, 10, 0.0420562996530461, 0.02095128323380625)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1127, 94, 11, 0.0420562996530461, 0.02087948113286751)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1128, 94, 12, 0.0420562996530461, 0.020807924247562861)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1129, 95, 1, 0.0420562996530461, 0.020736613451919652)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1130, 95, 2, 0.0420562996530461, 0.0206655470453618)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1131, 95, 3, 0.0420562996530461, 0.020594723341924318)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1132, 95, 4, 0.0420562996530461, 0.020524143206679141)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1133, 95, 5, 0.0420562996530461, 0.020453804956474527)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1134, 95, 6, 0.0420562996530461, 0.020383706922620128)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1135, 95, 7, 0.0420562996530461, 0.020313849961324227)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1136, 95, 8, 0.0420562996530461, 0.020244232406680895)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1137, 95, 9, 0.0420562996530461, 0.020174852607097411)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1138, 95, 10, 0.0420562996530461, 0.020105711410009233)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1139, 95, 11, 0.0420562996530461, 0.020036807166579539)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1140, 95, 12, 0.0420562996530461, 0.019968138242138056)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1141, 96, 1, 0.0420562996530461, 0.0198997054754373)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1142, 96, 2, 0.0420562996530461, 0.019831507234534661)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1143, 96, 3, 0.0420562996530461, 0.019763541901508926)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1144, 96, 4, 0.0420562996530461, 0.019695810306518638)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1145, 96, 5, 0.0420562996530461, 0.0196283108343423)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1146, 96, 6, 0.0420562996530461, 0.019561041883636141)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1147, 96, 7, 0.0420562996530461, 0.019494004276052791)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1148, 96, 8, 0.0420562996530461, 0.019427196412920528)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1149, 96, 9, 0.0420562996530461, 0.019360616709303186)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1150, 96, 10, 0.0420562996530461, 0.019294265978434616)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1151, 96, 11, 0.0420562996530461, 0.019228142638023318)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1152, 96, 12, 0.0420562996530461, 0.019162245119372603)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1153, 97, 1, 0.0420562996530461, 0.019096574227383811)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1154, 97, 2, 0.0420562996530461, 0.019031128395977825)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1155, 97, 3, 0.0420562996530461, 0.018965906072531034)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1156, 97, 4, 0.0420562996530461, 0.018900908053697658)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1157, 97, 5, 0.0420562996530461, 0.018836132789444841)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1158, 97, 6, 0.0420562996530461, 0.01877157874305737)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1159, 97, 7, 0.0420562996530461, 0.018707246703026835)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1160, 97, 8, 0.0420562996530461, 0.018643135135202233)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1161, 97, 9, 0.0420562996530461, 0.018579242518613752)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1162, 97, 10, 0.0420562996530461, 0.018515569633673984)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1163, 97, 11, 0.0420562996530461, 0.018452114961951052)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1164, 97, 12, 0.0420562996530461, 0.018388876998059217)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1165, 98, 1, 0.0420562996530461, 0.018325856514414856)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1166, 98, 2, 0.0420562996530461, 0.01826305200814415)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1167, 98, 3, 0.0420562996530461, 0.018200461989285759)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1168, 98, 4, 0.0420562996530461, 0.018138087222341771)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1169, 98, 5, 0.0420562996530461, 0.018075926219837023)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1170, 98, 6, 0.0420562996530461, 0.018013977507076531)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1171, 98, 7, 0.0420562996530461, 0.017952241840729178)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1172, 98, 8, 0.0420562996530461, 0.017890717748560696)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1173, 98, 9, 0.0420562996530461, 0.017829403770986015)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1174, 98, 10, 0.0420562996530461, 0.017768300656921095)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1175, 98, 11, 0.0420562996530461, 0.017707406949216378)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1176, 98, 12, 0.0420562996530461, 0.017646721203241914)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1177, 99, 1, 0.0420562996530461, 0.017586244160240162)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1178, 99, 2, 0.0420562996530461, 0.017525974377991724)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1179, 99, 3, 0.0420562996530461, 0.017465910426668528)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1180, 99, 4, 0.0420562996530461, 0.017406053039918157)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1181, 99, 5, 0.0420562996530461, 0.0173464007902984)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1182, 99, 6, 0.0420562996530461, 0.0172869522626314)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1183, 99, 7, 0.0420562996530461, 0.017227708183047693)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1184, 99, 8, 0.0420562996530461, 0.017168667138730827)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1185, 99, 9, 0.0420562996530461, 0.017109827729003067)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1186, 99, 10, 0.0420562996530461, 0.017051190672554905)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1187, 99, 11, 0.0420562996530461, 0.01699275457104581)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1188, 99, 12, 0.0420562996530461, 0.016934518038149583)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1189, 100, 1, 0.0420562996530461, 0.016876481785192916)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1190, 100, 2, 0.0420562996530461, 0.016818644428162874)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1191, 100, 3, 0.0420562996530461, 0.016761004594937744)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1192, 100, 4, 0.0420562996530461, 0.016703562989555866)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1193, 100, 5, 0.0420562996530461, 0.0166463182421851)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1194, 100, 6, 0.0420562996530461, 0.016589268994762676)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1195, 100, 7, 0.0420562996530461, 0.016532415944113268)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1196, 100, 8, 0.0420562996530461, 0.016475757734440218)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1197, 100, 9, 0.0420562996530461, 0.016419293021595671)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1198, 100, 10, 0.0420562996530461, 0.016363022495264525)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1199, 100, 11, 0.0420562996530461, 0.016306944813541811)
GO
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1200, 100, 12, 0.0420562996530461, 0.016251058646051995)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1201, 101, 1, 0.0420562996530461, 0.016195364675413375)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1202, 101, 2, 0.0420562996530461, 0.016139861573470322)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1203, 101, 3, 0.0420562996530461, 0.016084548023478522)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1204, 101, 4, 0.0420562996530461, 0.016029424701062063)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1205, 101, 5, 0.0420562996530461, 0.01597449029167379)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1206, 101, 6, 0.0420562996530461, 0.015919743492060934)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1207, 101, 7, 0.0420562996530461, 0.015865184970925043)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1208, 101, 8, 0.0420562996530461, 0.015810813427187997)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1209, 101, 9, 0.0420562996530461, 0.015756627570950338)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1210, 101, 10, 0.0420562996530461, 0.015702628064062005)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1211, 101, 11, 0.0420562996530461, 0.015648813618775903)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1212, 101, 12, 0.0420562996530461, 0.015595182958409068)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1213, 102, 1, 0.0420562996530461, 0.01554173673803003)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1214, 102, 2, 0.0420562996530461, 0.015488473683086134)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1215, 102, 3, 0.0420562996530461, 0.015435392529975485)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1216, 102, 4, 0.0420562996530461, 0.015382493927054691)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1217, 102, 5, 0.0420562996530461, 0.01532977661283034)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1218, 102, 6, 0.0420562996530461, 0.015277239336647579)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1219, 102, 7, 0.0420562996530461, 0.015224882740219868)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1220, 102, 8, 0.0420562996530461, 0.015172705574979229)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1221, 102, 9, 0.0420562996530461, 0.015120706603085194)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1222, 102, 10, 0.0420562996530461, 0.015068886459676138)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1223, 102, 11, 0.0420562996530461, 0.015017243908977082)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1224, 102, 12, 0.0420562996530461, 0.014965777725830652)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1225, 103, 1, 0.0420562996530461, 0.0149144885388675)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1226, 103, 2, 0.0420562996530461, 0.014863375124974572)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1227, 103, 3, 0.0420562996530461, 0.01481243627154763)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1228, 103, 4, 0.0420562996530461, 0.014761672600776285)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1229, 103, 5, 0.0420562996530461, 0.014711082902079675)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1230, 103, 6, 0.0420562996530461, 0.01466066597527807)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1231, 103, 7, 0.0420562996530461, 0.014610422436186042)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1232, 103, 8, 0.0420562996530461, 0.014560351086626509)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1233, 103, 9, 0.0420562996530461, 0.014510450738716952)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1234, 103, 10, 0.0420562996530461, 0.014460722001962219)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1235, 103, 11, 0.0420562996530461, 0.01441116369046192)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1236, 103, 12, 0.0420562996530461, 0.014361774628504742)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1237, 104, 1, 0.0420562996530461, 0.014312555419350467)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1238, 104, 2, 0.0420562996530461, 0.014263504889249604)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1239, 104, 3, 0.0420562996530461, 0.014214621874537344)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1240, 104, 4, 0.0420562996530461, 0.014165906972292383)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1241, 104, 5, 0.0420562996530461, 0.01411735902079163)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1242, 104, 6, 0.0420562996530461, 0.014068976868293351)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1243, 104, 7, 0.0420562996530461, 0.014020761105758488)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1244, 104, 8, 0.0420562996530461, 0.013972710583367133)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1245, 104, 9, 0.0420562996530461, 0.013924824161178455)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1246, 104, 10, 0.0420562996530461, 0.013877102424098328)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1247, 104, 11, 0.0420562996530461, 0.013829544234088057)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1248, 104, 12, 0.0420562996530461, 0.013782148462886808)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1249, 105, 1, 0.0420562996530461, 0.013734915689407426)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1250, 105, 2, 0.0420562996530461, 0.013687844787271721)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1251, 105, 3, 0.0420562996530461, 0.013640934639779176)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1252, 105, 4, 0.0420562996530461, 0.013594185819911016)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1253, 105, 5, 0.0420562996530461, 0.013547597212830076)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1254, 105, 6, 0.0420562996530461, 0.013501167713277713)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1255, 105, 7, 0.0420562996530461, 0.013454897888364304)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1256, 105, 8, 0.0420562996530461, 0.013408786634675464)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1257, 105, 9, 0.0420562996530461, 0.01336283285827718)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1258, 105, 10, 0.0420562996530461, 0.01331703712046914)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1259, 105, 11, 0.0420562996530461, 0.013271398329142698)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1260, 105, 12, 0.0420562996530461, 0.01322591540157244)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1261, 106, 1, 0.0420562996530461, 0.0131805888933069)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1262, 106, 2, 0.0420562996530461, 0.01313541772342733)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1263, 106, 3, 0.0420562996530461, 0.013090400820302071)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1264, 106, 4, 0.0420562996530461, 0.013045538733787433)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1265, 106, 5, 0.0420562996530461, 0.013000830394039906)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1266, 106, 6, 0.0420562996530461, 0.012956274740407926)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1267, 106, 7, 0.0420562996530461, 0.012911872317113892)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1268, 106, 8, 0.0420562996530461, 0.012867622065276066)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1269, 106, 9, 0.0420562996530461, 0.012823522935110467)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1270, 106, 10, 0.0420562996530461, 0.012779575465263312)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1271, 106, 11, 0.0420562996530461, 0.012735778607702315)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1272, 106, 12, 0.0420562996530461, 0.01269213132339973)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1273, 107, 1, 0.0420562996530461, 0.012648634145482729)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1274, 107, 2, 0.0420562996530461, 0.012605286036657313)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1275, 107, 3, 0.0420562996530461, 0.012562085968541756)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1276, 107, 4, 0.0420562996530461, 0.012519034468800736)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1277, 107, 5, 0.0420562996530461, 0.012476130510768516)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1278, 107, 6, 0.0420562996530461, 0.012433373076600309)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1279, 107, 7, 0.0420562996530461, 0.012390762688554272)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1280, 107, 8, 0.0420562996530461, 0.012348298330484023)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1281, 107, 9, 0.0420562996530461, 0.01230597899497376)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1282, 107, 10, 0.0420562996530461, 0.012263805198930507)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1283, 107, 11, 0.0420562996530461, 0.01222177593661946)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1284, 107, 12, 0.0420562996530461, 0.012179890210946943)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1285, 108, 1, 0.0420562996530461, 0.012138148533523676)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1286, 108, 2, 0.0420562996530461, 0.012096549908919757)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1287, 108, 3, 0.0420562996530461, 0.012055093350257867)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1288, 108, 4, 0.0420562996530461, 0.012013779363906695)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1289, 108, 5, 0.0420562996530461, 0.011972606964635653)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1290, 108, 6, 0.0420562996530461, 0.011931575175679103)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1291, 108, 7, 0.0420562996530461, 0.01189068449821741)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1292, 108, 8, 0.0420562996530461, 0.011849933957114797)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1293, 108, 9, 0.0420562996530461, 0.011809322585613706)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1294, 108, 10, 0.0420562996530461, 0.011768850879759334)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1295, 108, 11, 0.0420562996530461, 0.011728517874407282)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1296, 108, 12, 0.0420562996530461, 0.011688322612705526)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1297, 109, 1, 0.0420562996530461, 0.011648265585616716)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1298, 109, 2, 0.0420562996530461, 0.011608345837885456)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1299, 109, 3, 0.0420562996530461, 0.011568562422463765)
GO
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1300, 109, 4, 0.0420562996530461, 0.011528915825283816)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1301, 109, 5, 0.0420562996530461, 0.011489405100877896)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1302, 109, 6, 0.0420562996530461, 0.011450029311901609)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1303, 109, 7, 0.0420562996530461, 0.011410788939308202)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1304, 109, 8, 0.0420562996530461, 0.011371683047317355)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1305, 109, 9, 0.0420562996530461, 0.011332710708188832)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1306, 109, 10, 0.0420562996530461, 0.011293872397947968)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1307, 109, 11, 0.0420562996530461, 0.011255167190402579)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1308, 109, 12, 0.0420562996530461, 0.011216594167318184)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1309, 110, 1, 0.0420562996530461, 0.011178153799842697)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1310, 110, 2, 0.0420562996530461, 0.011139845171273827)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1311, 110, 3, 0.0420562996530461, 0.011101667372785454)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1312, 110, 4, 0.0420562996530461, 0.011063620870698045)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1313, 110, 5, 0.0420562996530461, 0.011025704757701968)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1314, 110, 6, 0.0420562996530461, 0.010987918134283061)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1315, 110, 7, 0.0420562996530461, 0.01095026146198381)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1316, 110, 8, 0.0420562996530461, 0.010912733842791001)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1317, 110, 9, 0.0420562996530461, 0.010875334386407023)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1318, 110, 10, 0.0420562996530461, 0.010838063549645328)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1319, 110, 11, 0.0420562996530461, 0.010800920443693877)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1320, 110, 12, 0.0420562996530461, 0.010763904187377172)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1321, 111, 1, 0.0420562996530461, 0.01072701523282809)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1322, 111, 2, 0.0420562996530461, 0.01069025270034148)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1323, 111, 3, 0.0420562996530461, 0.010653615717770498)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1324, 111, 4, 0.0420562996530461, 0.010617104732615398)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1325, 111, 5, 0.0420562996530461, 0.010580718874184618)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1326, 111, 6, 0.0420562996530461, 0.010544457279267448)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1327, 111, 7, 0.0420562996530461, 0.010508320390778994)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1328, 111, 8, 0.0420562996530461, 0.010472307346948921)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1329, 111, 9, 0.0420562996530461, 0.010436417293411094)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1330, 111, 10, 0.0420562996530461, 0.010400650668542453)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1331, 111, 11, 0.0420562996530461, 0.010365006619402482)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1332, 111, 12, 0.0420562996530461, 0.010329484300379)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1333, 112, 1, 0.0420562996530461, 0.010294084145357273)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1334, 112, 2, 0.0420562996530461, 0.010258805310136137)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1335, 112, 3, 0.0420562996530461, 0.010223646957767668)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1336, 112, 4, 0.0420562996530461, 0.010188609517691488)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1337, 112, 5, 0.0420562996530461, 0.010153692154356232)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1338, 112, 6, 0.0420562996530461, 0.010118894039389464)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1339, 112, 7, 0.0420562996530461, 0.010084215597830706)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1340, 112, 8, 0.0420562996530461, 0.010049656002689767)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1341, 112, 9, 0.0420562996530461, 0.010015214434081838)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1342, 112, 10, 0.0420562996530461, 0.00998089131269142)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1343, 112, 11, 0.0420562996530461, 0.009946685820001782)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1344, 112, 12, 0.0420562996530461, 0.0099125971445287678)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1345, 113, 1, 0.0420562996530461, 0.00987862570264649)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1346, 113, 2, 0.0420562996530461, 0.0098447706842248531)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1347, 113, 3, 0.0420562996530461, 0.009811031286094278)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1348, 113, 4, 0.0420562996530461, 0.00977740792036265)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1349, 113, 5, 0.0420562996530461, 0.0097438997852005837)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1350, 113, 6, 0.0420562996530461, 0.0097105060856678884)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1351, 113, 7, 0.0420562996530461, 0.0096772272296499311)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1352, 113, 8, 0.0420562996530461, 0.0096440624235329831)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1353, 113, 9, 0.0420562996530461, 0.00961101088052192)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1354, 113, 10, 0.0420562996530461, 0.0095780730043228662)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1355, 113, 11, 0.0420562996530461, 0.0095452480094535622)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1356, 113, 12, 0.0420562996530461, 0.0095125351171805022)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1357, 114, 1, 0.0420562996530461, 0.0094799347270733744)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1358, 114, 2, 0.0420562996530461, 0.0094474460616980876)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1359, 114, 3, 0.0420562996530461, 0.0094150683503001452)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1360, 114, 4, 0.0420562996530461, 0.009382801988355189)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1361, 114, 5, 0.0420562996530461, 0.0093506462063948255)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1362, 114, 6, 0.0420562996530461, 0.0093186002415618172)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1363, 114, 7, 0.0420562996530461, 0.0092866644852797071)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1364, 114, 8, 0.0420562996530461, 0.0092548381759641838)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1365, 114, 9, 0.0420562996530461, 0.00922312055857435)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1366, 114, 10, 0.0420562996530461, 0.0091915120205231689)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1367, 114, 11, 0.0420562996530461, 0.0091600118080296285)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1368, 114, 12, 0.0420562996530461, 0.0091286191737890866)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1369, 115, 1, 0.0420562996530461, 0.00909733450124502)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1370, 115, 2, 0.0420562996530461, 0.0090661570443397611)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1371, 115, 3, 0.0420562996530461, 0.0090350860634256548)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1372, 115, 4, 0.0420562996530461, 0.0090041219380173655)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1373, 115, 5, 0.0420562996530461, 0.0089732639297014326)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1374, 115, 6, 0.0420562996530461, 0.0089425113064087389)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1375, 115, 7, 0.0420562996530461, 0.0089118644437653841)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1376, 115, 8, 0.0420562996530461, 0.0088813226109237982)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1377, 115, 9, 0.0420562996530461, 0.0088508850833157477)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1378, 115, 10, 0.0420562996530461, 0.00882055223271861)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1379, 115, 11, 0.0420562996530461, 0.008790323335773188)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1380, 115, 12, 0.0420562996530461, 0.00876019767533527)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1381, 116, 1, 0.0420562996530461, 0.0087301756193729554)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1382, 116, 2, 0.0420562996530461, 0.0087002564519386809)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1383, 116, 3, 0.0420562996530461, 0.0086704394632361979)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1384, 116, 4, 0.0420562996530461, 0.0086407250174633556)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1385, 116, 5, 0.0420562996530461, 0.0086111124060082866)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1386, 116, 6, 0.0420562996530461, 0.0085816009263474137)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1387, 116, 7, 0.0420562996530461, 0.0085521909389469648)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1388, 116, 8, 0.0420562996530461, 0.00852288174245561)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1389, 116, 9, 0.0420562996530461, 0.0084936726415479284)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1390, 116, 10, 0.0420562996530461, 0.0084645639929967556)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1391, 116, 11, 0.0420562996530461, 0.0084355551026369085)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1392, 116, 12, 0.0420562996530461, 0.0084066452822673682)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1393, 117, 1, 0.0420562996530461, 0.0083778348850054238)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1394, 117, 2, 0.0420562996530461, 0.0083491232237984086)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1395, 117, 3, 0.0420562996530461, 0.008320509617496705)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1396, 117, 4, 0.0420562996530461, 0.0082919944155995171)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1397, 117, 5, 0.0420562996530461, 0.0082635769380938126)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1398, 117, 6, 0.0420562996530461, 0.0082352565108091275)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1399, 117, 7, 0.0420562996530461, 0.00820703347966365)
GO
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1400, 117, 8, 0.0420562996530461, 0.0081789071716118558)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1401, 117, 9, 0.0420562996530461, 0.0081508769193909276)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1402, 117, 10, 0.0420562996530461, 0.0081229430653747235)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1403, 117, 11, 0.0420562996530461, 0.0080951049434138424)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1404, 117, 12, 0.0420562996530461, 0.0080673618930823324)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1405, 118, 1, 0.0420562996530461, 0.0080397142532460438)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1406, 118, 2, 0.0420562996530461, 0.00801216136458103)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1407, 118, 3, 0.0420562996530461, 0.0079847025734281624)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1408, 118, 4, 0.0420562996530461, 0.0079573382151812214)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1409, 118, 5, 0.0420562996530461, 0.0079300676372717864)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1410, 118, 6, 0.0420562996530461, 0.00790289019273821)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1411, 118, 7, 0.0420562996530461, 0.0078758062135377838)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1412, 118, 8, 0.0420562996530461, 0.0078488150537883924)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1413, 118, 9, 0.0420562996530461, 0.00782191607315725)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1414, 118, 10, 0.0420562996530461, 0.0077951096002003622)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1415, 118, 11, 0.0420562996530461, 0.0077683949956534187)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1416, 118, 12, 0.0420562996530461, 0.00774177162574457)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1417, 119, 1, 0.0420562996530461, 0.0077152398156633923)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1418, 119, 2, 0.0420562996530461, 0.0076887989326955659)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1419, 119, 3, 0.0420562996530461, 0.0076624483495629555)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1420, 119, 4, 0.0420562996530461, 0.0076361883881232015)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1421, 119, 5, 0.0420562996530461, 0.0076100184221448621)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1422, 119, 6, 0.0420562996530461, 0.0075839378307769826)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1423, 119, 7, 0.0420562996530461, 0.0075579469325794037)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1424, 119, 8, 0.0420562996530461, 0.00753204510773714)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1425, 119, 9, 0.0420562996530461, 0.0075062317417605605)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1426, 119, 10, 0.0420562996530461, 0.0074805071499455)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1427, 119, 11, 0.0420562996530461, 0.0074548707188276829)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1428, 119, 12, 0.0420562996530461, 0.0074293218402136261)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1429, 120, 1, 0.0420562996530461, 0.007403860826168597)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1430, 120, 2, 0.0420562996530461, 0.0073784870695139618)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1431, 120, 3, 0.0420562996530461, 0.0073531999682878721)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1432, 120, 4, 0.0420562996530461, 0.0073279998313581333)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1433, 120, 5, 0.0420562996530461, 0.0073028860577673471)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1434, 120, 6, 0.0420562996530461, 0.0072778580517214508)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1435, 120, 7, 0.0420562996530461, 0.0072529161189235471)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1436, 120, 8, 0.0420562996530461, 0.0072280596645737313)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1437, 120, 9, 0.0420562996530461, 0.0072032880989825309)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1438, 120, 10, 0.0420562996530461, 0.007178601724720771)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1439, 120, 11, 0.0420562996530461, 0.00715399995308295)
INSERT [qte].[SpotInterest] ([RateVersionID], [AnnuityAccumMonth], [AnnuityYear], [AnnuityMonth], [DiscountRate], [SpotInterestVx]) VALUES (1, 1440, 120, 12, 0.0420562996530461, 0.0071294822004216354)
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 1, CAST(0.02430000000000000 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 2, CAST(0.02762604707282020 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 3, CAST(0.03046322740404410 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 4, CAST(0.03275799397926590 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 5, CAST(0.03505276055448770 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 6, CAST(0.03695055815312180 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 7, CAST(0.03784835575175580 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 8, CAST(0.03812285231505200 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 9, CAST(0.03839734887834810 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 10, CAST(0.03867184544164430 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 11, CAST(0.03886516288174190 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 12, CAST(0.03905848032183950 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 13, CAST(0.03925179776193710 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 14, CAST(0.03944511520203470 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 15, CAST(0.03963843264213230 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 16, CAST(0.03983175008222990 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 17, CAST(0.04002506752232750 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 18, CAST(0.04021838496242510 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 19, CAST(0.04041170240252270 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 20, CAST(0.04060501984262030 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 21, CAST(0.04075014782366290 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 22, CAST(0.04089527580470550 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 23, CAST(0.04104040378574810 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 24, CAST(0.04118553176679070 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 25, CAST(0.04133065974783320 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 26, CAST(0.04147578772887580 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 27, CAST(0.04162091570991840 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 28, CAST(0.04176604369096100 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 29, CAST(0.04191117167200360 AS Decimal(19, 17)))
INSERT [qte].[SpotRate] ([SpotRateHdrID], [AnnuityYear], [SpotRate]) VALUES (1, 30, CAST(0.04205629965304610 AS Decimal(19, 17)))
SET IDENTITY_INSERT [qte].[SpotRateHdr] ON 

INSERT [qte].[SpotRateHdr] ([SpotRateHdrID], [SpotRateDescr], [DateCreated]) VALUES (1, N'20180222.sr', CAST(0x0790D5ADEA41F43D0B AS DateTime2))
SET IDENTITY_INSERT [qte].[SpotRateHdr] OFF
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 0, 0, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 1, 0.25, 0.75)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 2, 0.5, 0.5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 3, 0.55, 0.45)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 4, 0.6, 0.4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 5, 0.65, 0.35)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 6, 0.7, 0.3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 7, 0.75, 0.25)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 8, 0.8, 0.2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 9, 0.85, 0.15)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 10, 0.9, 0.1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 11, 0.95, 0.05)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 12, 1, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 13, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 14, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 15, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 16, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 17, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 18, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 19, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 20, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 21, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 22, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 23, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 24, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 25, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 26, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 27, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 28, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 29, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 30, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 31, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 32, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 33, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 34, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 35, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 36, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 37, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 38, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 39, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 40, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 41, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 42, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 43, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 44, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 45, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 46, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 47, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 48, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 49, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 50, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 51, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 52, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 53, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 54, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 55, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 56, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 57, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 58, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 59, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 60, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 61, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 62, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 63, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 64, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 65, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 66, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 67, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 68, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 69, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 70, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 71, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 72, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 73, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 74, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 75, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 76, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 77, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 78, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 79, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 80, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 81, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 82, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 83, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 84, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 85, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 86, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 87, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 88, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 89, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 90, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 91, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 92, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 93, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 94, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 95, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 96, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 97, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 98, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 99, 3, 9)
GO
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 100, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 101, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 102, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 103, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 104, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 105, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 106, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 107, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 108, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 109, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 110, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 111, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 112, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 113, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 114, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 115, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 116, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 117, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 118, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 119, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 120, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 121, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 122, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 123, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 124, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 125, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 126, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 127, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 128, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 129, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 130, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 131, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 132, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 133, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 134, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 135, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 136, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 137, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 138, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 139, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 140, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 141, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 142, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 143, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 144, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 145, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 146, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 147, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 148, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 149, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 150, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 151, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 152, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 153, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 154, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 155, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 156, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 157, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 158, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 159, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 160, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 161, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 162, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 163, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 164, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 165, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 166, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 167, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 168, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 169, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 170, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 171, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 172, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 173, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 174, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 175, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 176, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 177, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 178, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 179, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 180, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 181, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 182, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 183, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 184, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 185, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 186, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 187, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 188, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 189, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 190, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 191, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 192, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 193, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 194, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 195, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 196, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 197, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 198, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 199, 7, 5)
GO
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 200, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 201, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 202, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 203, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 204, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 205, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 206, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 207, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 208, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 209, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 210, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 211, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 212, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 213, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 214, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 215, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 216, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 217, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 218, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 219, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 220, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 221, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 222, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 223, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 224, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 225, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 226, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 227, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 228, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 229, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 230, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 231, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 232, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 233, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 234, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 235, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 236, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 237, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 238, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 239, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 240, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 241, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 242, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 243, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 244, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 245, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 246, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 247, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 248, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 249, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 250, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 251, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 252, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 253, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 254, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 255, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 256, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 257, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 258, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 259, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 260, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 261, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 262, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 263, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 264, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 265, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 266, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 267, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 268, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 269, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 270, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 271, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 272, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 273, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 274, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 275, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 276, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 277, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 278, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 279, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 280, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 281, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 282, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 283, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 284, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 285, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 286, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 287, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 288, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 289, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 290, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 291, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 292, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 293, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 294, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 295, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 296, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 297, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 298, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 299, 11, 1)
GO
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 300, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 301, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 302, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 303, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 304, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 305, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 306, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 307, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 308, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 309, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 310, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 311, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 312, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 313, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 314, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 315, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 316, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 317, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 318, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 319, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 320, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 321, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 322, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 323, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 324, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 325, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 326, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 327, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 328, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 329, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 330, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 331, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 332, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 333, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 334, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 335, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 336, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 337, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 338, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 339, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 340, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 341, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 342, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 343, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 344, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 345, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 346, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 347, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 348, 12, 0)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 349, 1, 11)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 350, 2, 10)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 351, 3, 9)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 352, 4, 8)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 353, 5, 7)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 354, 6, 6)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 355, 7, 5)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 356, 8, 4)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 357, 9, 3)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 358, 10, 2)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 359, 11, 1)
INSERT [qte].[SpotWeight] ([SpotWeightHdrID], [AnnuityAccumMonth], [Weight1], [Weight2]) VALUES (1, 360, 12, 0)
SET IDENTITY_INSERT [qte].[SpotWeightHdr] ON 

INSERT [qte].[SpotWeightHdr] ([SpotWeightHdrID], [SpotWeightDescr], [DateCreated]) VALUES (1, N'20180222.sw', CAST(0x0770F8AFEA41F43D0B AS DateTime2))
SET IDENTITY_INSERT [qte].[SpotWeightHdr] OFF
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'AK', N'Alaska')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'AL', N'Alabama')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'AR', N'Arkansas')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'AZ', N'Arizona')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'CA', N'California')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'CO', N'Colorado')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'CT', N'Connecticut')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'DE', N'Delaware')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'FL', N'Florida')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'GA', N'Georgia')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'HI', N'Hawaii')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'IA', N'Iowa')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'ID', N'Idaho')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'IL', N'Illinois')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'IN', N'Indiana')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'KS', N'Kansas')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'KY', N'Kentucky')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'LA', N'Louisiana')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'MA', N'Massachusetts')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'MD', N'Maryland')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'ME', N'Maine')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'MI', N'Michigan')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'MN', N'Minnesota')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'MO', N'Missouri')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'MS', N'Mississippi')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'MT', N'Montana')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'NC', N'North Carolina')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'ND', N'North Dakota')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'NE', N'Nebraska')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'NH', N'New Hampshire')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'NJ', N'New Jersey')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'NM', N'New Mexico')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'NV', N'Nevada')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'NY', N'New York')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'OH', N'Ohio')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'OK', N'Oklahoma')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'OR', N'Oregon')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'PA', N'Pennsylvania')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'RI', N'Rhode Island')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'SC', N'South Carolina')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'SD', N'South Dakota')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'TN', N'Tennessee')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'TX', N'Texas')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'UT', N'Utah')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'VA', N'Virginia')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'VT', N'Vermont')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'WA', N'Washington')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'WI', N'Wisconsin')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'WV', N'West Virginia')
INSERT [qte].[StateCode] ([StateCode], [StateName]) VALUES (N'WY', N'Wyoming')
SET IDENTITY_INSERT [qte].[StlmtBroker] ON 

INSERT [qte].[StlmtBroker] ([StlmtBrokerID], [FirstName], [MiddleInitial], [LastName], [EntityName], [AddrLine1], [AddrLine2], [AddrLine3], [City], [StateCode], [ZipCode5], [PhoneNum]) VALUES (1, N'', NULL, N'', N'Default Broker', N'P.O. Box 679053', NULL, NULL, N'Dallas', N'TX', N'75267', N'8007930848')
SET IDENTITY_INSERT [qte].[StlmtBroker] OFF
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_Annuitant_QuoteFirstLast]    Script Date: 3/7/2018 10:48:25 AM ******/
ALTER TABLE [qte].[Annuitant] ADD  CONSTRAINT [IX_Annuitant_QuoteFirstLast] UNIQUE NONCLUSTERED 
(
	[QuoteID] ASC,
	[FirstName] ASC,
	[LastName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_Benefit_BenefitDescr]    Script Date: 3/7/2018 10:48:25 AM ******/
ALTER TABLE [qte].[Benefit] ADD  CONSTRAINT [IX_Benefit_BenefitDescr] UNIQUE NONCLUSTERED 
(
	[BenefitDescr] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
/****** Object:  Index [IX_Benefit_DropDownOrder]    Script Date: 3/7/2018 10:48:25 AM ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_Benefit_DropDownOrder] ON [qte].[Benefit]
(
	[DropDownOrder] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_MortalityHdr_Descr]    Script Date: 3/7/2018 10:48:25 AM ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_MortalityHdr_Descr] ON [qte].[MortalityHdr]
(
	[MortalityDescr] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
/****** Object:  Index [IX_PaymentStream_BenefitQuoteID]    Script Date: 3/7/2018 10:48:25 AM ******/
CREATE NONCLUSTERED INDEX [IX_PaymentStream_BenefitQuoteID] ON [qte].[PaymentStream]
(
	[BenefitQuoteID] ASC
)
INCLUDE ( 	[PaymentStreamID]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_RateVersion_Descr]    Script Date: 3/7/2018 10:48:25 AM ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_RateVersion_Descr] ON [qte].[RateVersion]
(
	[RateDescr] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [IX_SpotRateHdr_Descr]    Script Date: 3/7/2018 10:48:25 AM ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_SpotRateHdr_Descr] ON [qte].[SpotRateHdr]
(
	[SpotRateDescr] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[dba_errorLog] ADD  CONSTRAINT [DF_errorLog_errorType]  DEFAULT ('sys') FOR [errorType]
GO
ALTER TABLE [dbo].[dba_errorLog] ADD  CONSTRAINT [DF_errorLog_errorDate]  DEFAULT (getdate()) FOR [errorDate]
GO
ALTER TABLE [qte].[Improvement] ADD  CONSTRAINT [DF_Improvement_DateCreated]  DEFAULT (sysdatetime()) FOR [DateCreated]
GO
ALTER TABLE [qte].[MortalityHdr] ADD  CONSTRAINT [DF_MortalityHdr_DateCreated]  DEFAULT (sysdatetime()) FOR [DateCreated]
GO
ALTER TABLE [qte].[ProcedureLog] ADD  CONSTRAINT [DF_ProcedureLog_TransactionDate]  DEFAULT (sysdatetime()) FOR [TransactionDate]
GO
ALTER TABLE [qte].[Quote] ADD  CONSTRAINT [DF_Quote_DateCreated]  DEFAULT (sysdatetime()) FOR [DateCreated]
GO
ALTER TABLE [qte].[RateVersion] ADD  CONSTRAINT [DF_RateVersion_DateCreated]  DEFAULT (sysdatetime()) FOR [DateCreated]
GO
ALTER TABLE [qte].[SpotRateHdr] ADD  CONSTRAINT [DF_SpotRateHdr_DateCreated]  DEFAULT (sysdatetime()) FOR [DateCreated]
GO
ALTER TABLE [qte].[SpotWeightHdr] ADD  CONSTRAINT [DF_SpotWeightHdr_DateCreated]  DEFAULT (sysdatetime()) FOR [DateCreated]
GO
ALTER TABLE [qte].[Annuitant]  WITH CHECK ADD  CONSTRAINT [FK_Annuitant_Quote] FOREIGN KEY([QuoteID])
REFERENCES [qte].[Quote] ([QuoteID])
GO
ALTER TABLE [qte].[Annuitant] CHECK CONSTRAINT [FK_Annuitant_Quote]
GO
ALTER TABLE [qte].[BenefitQuote]  WITH CHECK ADD  CONSTRAINT [FK_BenefitQuote_Benefit] FOREIGN KEY([BenefitID])
REFERENCES [qte].[Benefit] ([BenefitID])
GO
ALTER TABLE [qte].[BenefitQuote] CHECK CONSTRAINT [FK_BenefitQuote_Benefit]
GO
ALTER TABLE [qte].[BenefitQuote]  WITH CHECK ADD  CONSTRAINT [FK_BenefitQuote_JointAnnuitant] FOREIGN KEY([JointAnnuitantID])
REFERENCES [qte].[Annuitant] ([AnnuitantID])
GO
ALTER TABLE [qte].[BenefitQuote] CHECK CONSTRAINT [FK_BenefitQuote_JointAnnuitant]
GO
ALTER TABLE [qte].[BenefitQuote]  WITH CHECK ADD  CONSTRAINT [FK_BenefitQuote_PrimaryAnnuitant] FOREIGN KEY([PrimaryAnnuitantID])
REFERENCES [qte].[Annuitant] ([AnnuitantID])
GO
ALTER TABLE [qte].[BenefitQuote] CHECK CONSTRAINT [FK_BenefitQuote_PrimaryAnnuitant]
GO
ALTER TABLE [qte].[BenefitQuote]  WITH CHECK ADD  CONSTRAINT [FK_BenefitQuote_Quote] FOREIGN KEY([QuoteID])
REFERENCES [qte].[Quote] ([QuoteID])
GO
ALTER TABLE [qte].[BenefitQuote] CHECK CONSTRAINT [FK_BenefitQuote_Quote]
GO
ALTER TABLE [qte].[LifeExpMultiple]  WITH CHECK ADD  CONSTRAINT [FK_LifeExpMultiple_Annuitant] FOREIGN KEY([AnnuitantID])
REFERENCES [qte].[Annuitant] ([AnnuitantID])
GO
ALTER TABLE [qte].[LifeExpMultiple] CHECK CONSTRAINT [FK_LifeExpMultiple_Annuitant]
GO
ALTER TABLE [qte].[Mortality]  WITH CHECK ADD  CONSTRAINT [FK_Mortality_MortalityHdr] FOREIGN KEY([MortalityHdrID])
REFERENCES [qte].[MortalityHdr] ([MortalityHdrID])
GO
ALTER TABLE [qte].[Mortality] CHECK CONSTRAINT [FK_Mortality_MortalityHdr]
GO
ALTER TABLE [qte].[PaymentStream]  WITH CHECK ADD  CONSTRAINT [FK_PaymentStream_BenefitQuote] FOREIGN KEY([BenefitQuoteID])
REFERENCES [qte].[BenefitQuote] ([BenefitQuoteID])
GO
ALTER TABLE [qte].[PaymentStream] CHECK CONSTRAINT [FK_PaymentStream_BenefitQuote]
GO
ALTER TABLE [qte].[Quote]  WITH CHECK ADD  CONSTRAINT [FK_Quote_RateVersion] FOREIGN KEY([RateVersionID])
REFERENCES [qte].[RateVersion] ([RateVersionID])
GO
ALTER TABLE [qte].[Quote] CHECK CONSTRAINT [FK_Quote_RateVersion]
GO
ALTER TABLE [qte].[Quote]  WITH CHECK ADD  CONSTRAINT [FK_Quote_StlmtBroker] FOREIGN KEY([StlmtBrokerID])
REFERENCES [qte].[StlmtBroker] ([StlmtBrokerID])
GO
ALTER TABLE [qte].[Quote] CHECK CONSTRAINT [FK_Quote_StlmtBroker]
GO
ALTER TABLE [qte].[RateVersion]  WITH CHECK ADD  CONSTRAINT [FK_RateVersion_Improvement] FOREIGN KEY([ImprovementID])
REFERENCES [qte].[Improvement] ([ImprovementID])
GO
ALTER TABLE [qte].[RateVersion] CHECK CONSTRAINT [FK_RateVersion_Improvement]
GO
ALTER TABLE [qte].[RateVersion]  WITH CHECK ADD  CONSTRAINT [FK_RateVersion_MortalityHdr] FOREIGN KEY([MortalityHdrID])
REFERENCES [qte].[MortalityHdr] ([MortalityHdrID])
GO
ALTER TABLE [qte].[RateVersion] CHECK CONSTRAINT [FK_RateVersion_MortalityHdr]
GO
ALTER TABLE [qte].[RateVersion]  WITH CHECK ADD  CONSTRAINT [FK_RateVersion_SpotRateHdr] FOREIGN KEY([SpotRateHdrID])
REFERENCES [qte].[SpotRateHdr] ([SpotRateHdrID])
GO
ALTER TABLE [qte].[RateVersion] CHECK CONSTRAINT [FK_RateVersion_SpotRateHdr]
GO
ALTER TABLE [qte].[RateVersion]  WITH CHECK ADD  CONSTRAINT [FK_RateVersion_SpotWeightHdr] FOREIGN KEY([SpotWeightHdrID])
REFERENCES [qte].[SpotWeightHdr] ([SpotWeightHdrID])
GO
ALTER TABLE [qte].[RateVersion] CHECK CONSTRAINT [FK_RateVersion_SpotWeightHdr]
GO
ALTER TABLE [qte].[SpotInterest]  WITH CHECK ADD  CONSTRAINT [FK_SpotInterest_RateVersion] FOREIGN KEY([RateVersionID])
REFERENCES [qte].[RateVersion] ([RateVersionID])
GO
ALTER TABLE [qte].[SpotInterest] CHECK CONSTRAINT [FK_SpotInterest_RateVersion]
GO
ALTER TABLE [qte].[SpotRate]  WITH CHECK ADD  CONSTRAINT [FK_SpotRate_SpotRateHdr] FOREIGN KEY([SpotRateHdrID])
REFERENCES [qte].[SpotRateHdr] ([SpotRateHdrID])
GO
ALTER TABLE [qte].[SpotRate] CHECK CONSTRAINT [FK_SpotRate_SpotRateHdr]
GO
ALTER TABLE [qte].[SpotWeight]  WITH CHECK ADD  CONSTRAINT [FK_SpotWeight_SpotWeightHdr] FOREIGN KEY([SpotWeightHdrID])
REFERENCES [qte].[SpotWeightHdr] ([SpotWeightHdrID])
GO
ALTER TABLE [qte].[SpotWeight] CHECK CONSTRAINT [FK_SpotWeight_SpotWeightHdr]
GO
ALTER TABLE [qte].[StlmtBroker]  WITH CHECK ADD  CONSTRAINT [FK_StlmtBroker_StateCode] FOREIGN KEY([StateCode])
REFERENCES [qte].[StateCode] ([StateCode])
GO
ALTER TABLE [qte].[StlmtBroker] CHECK CONSTRAINT [FK_StlmtBroker_StateCode]
GO
ALTER TABLE [qte].[Annuitant]  WITH CHECK ADD  CONSTRAINT [CK_Annuitant_Gender] CHECK  (([Gender]='F' OR [Gender]='M'))
GO
ALTER TABLE [qte].[Annuitant] CHECK CONSTRAINT [CK_Annuitant_Gender]
GO
ALTER TABLE [qte].[Annuitant]  WITH CHECK ADD  CONSTRAINT [CK_Annuitant_RatedAge] CHECK  (([RatedAge]>=(0) AND [RatedAge]<=(99)))
GO
ALTER TABLE [qte].[Annuitant] CHECK CONSTRAINT [CK_Annuitant_RatedAge]
GO
ALTER TABLE [qte].[Mortality]  WITH CHECK ADD  CONSTRAINT [CK_Mortality_Gender] CHECK  (([Gender]='F' OR [Gender]='M'))
GO
ALTER TABLE [qte].[Mortality] CHECK CONSTRAINT [CK_Mortality_Gender]
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Gender must be either ''M'' or ''F''.' , @level0type=N'SCHEMA',@level0name=N'qte', @level1type=N'TABLE',@level1name=N'Mortality', @level2type=N'CONSTRAINT',@level2name=N'CK_Mortality_Gender'
GO
--USE [master]
--GO
--ALTER DATABASE [Quote] SET  READ_WRITE 
--GO
