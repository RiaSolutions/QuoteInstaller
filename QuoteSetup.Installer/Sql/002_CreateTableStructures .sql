/*

Script created by SQL Compare version 12.2.1.4077 from Red Gate Software Ltd at 3/5/2018 1:04:21 PM

*/
SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
SET XACT_ABORT ON
GO
SET TRANSACTION ISOLATION LEVEL Serializable
GO
BEGIN TRANSACTION
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [qte].[Quote]'
GO
CREATE TABLE [qte].[Quote]
(
[QuoteID] [int] NOT NULL IDENTITY(1, 1),
[QuoteDescr] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateCreated] [datetime2] NOT NULL CONSTRAINT [DF_Quote_DateCreated] DEFAULT (sysdatetime()),
[LastModified] [datetime2] NULL,
[RateVersionID] [int] NOT NULL,
[StlmtBrokerID] [int] NOT NULL,
[PurchaseDate] [date] NOT NULL,
[BudgetAmt] [decimal] (18, 2) NOT NULL
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_Quote] on [qte].[Quote]'
GO
ALTER TABLE [qte].[Quote] ADD CONSTRAINT [PK_Quote] PRIMARY KEY CLUSTERED  ([QuoteID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [qte].[RateVersion]'
GO
CREATE TABLE [qte].[RateVersion]
(
[RateVersionID] [int] NOT NULL IDENTITY(1, 1),
[RateDescr] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[SpotRateHdrID] [int] NOT NULL,
[MortalityHdrID] [int] NOT NULL,
[ImprovementID] [int] NOT NULL,
[SpotWeightHdrID] [int] NOT NULL,
[DateCreated] [datetime2] NOT NULL CONSTRAINT [DF_RateVersion_DateCreated] DEFAULT (sysdatetime())
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_RateVersion] on [qte].[RateVersion]'
GO
ALTER TABLE [qte].[RateVersion] ADD CONSTRAINT [PK_RateVersion] PRIMARY KEY CLUSTERED  ([RateVersionID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating index [IX_RateVersion_Descr] on [qte].[RateVersion]'
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_RateVersion_Descr] ON [qte].[RateVersion] ([RateDescr])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [qte].[ProcedureLog]'
GO
CREATE TABLE [qte].[ProcedureLog]
(
[ProcedureLogID] [int] NOT NULL IDENTITY(1, 1),
[TransactionDate] [datetime2] NOT NULL CONSTRAINT [DF_ProcedureLog_TransactionDate] DEFAULT (sysdatetime()),
[ProcedureName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[RunStart] [datetime2] NOT NULL,
[RunEnd] [datetime2] NOT NULL
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_ProcedureLog] on [qte].[ProcedureLog]'
GO
ALTER TABLE [qte].[ProcedureLog] ADD CONSTRAINT [PK_ProcedureLog] PRIMARY KEY CLUSTERED  ([ProcedureLogID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [qte].[MortalityHdr]'
GO
CREATE TABLE [qte].[MortalityHdr]
(
[MortalityHdrID] [int] NOT NULL IDENTITY(1, 1),
[MortalityDescr] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateCreated] [datetime2] NOT NULL CONSTRAINT [DF_MortalityHdr_DateCreated] DEFAULT (sysdatetime())
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_MortalityHdr] on [qte].[MortalityHdr]'
GO
ALTER TABLE [qte].[MortalityHdr] ADD CONSTRAINT [PK_MortalityHdr] PRIMARY KEY CLUSTERED  ([MortalityHdrID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating index [IX_MortalityHdr_Descr] on [qte].[MortalityHdr]'
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_MortalityHdr_Descr] ON [qte].[MortalityHdr] ([MortalityDescr])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [qte].[Mortality]'
GO
CREATE TABLE [qte].[Mortality]
(
[MortalityHdrID] [int] NOT NULL,
[Age] [tinyint] NOT NULL,
[Gender] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[MortalityPct] [decimal] (9, 6) NOT NULL
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_Mortality] on [qte].[Mortality]'
GO
ALTER TABLE [qte].[Mortality] ADD CONSTRAINT [PK_Mortality] PRIMARY KEY CLUSTERED  ([MortalityHdrID], [Age], [Gender])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [qte].[Improvement]'
GO
CREATE TABLE [qte].[Improvement]
(
[ImprovementID] [int] NOT NULL IDENTITY(1, 1),
[ImprovementDescr] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ImprovementPct] [decimal] (9, 6) NOT NULL,
[DateCreated] [datetime2] NOT NULL CONSTRAINT [DF_Improvement_DateCreated] DEFAULT (sysdatetime())
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_Improvement] on [qte].[Improvement]'
GO
ALTER TABLE [qte].[Improvement] ADD CONSTRAINT [PK_Improvement] PRIMARY KEY CLUSTERED  ([ImprovementID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [qte].[SpotWeight]'
GO
CREATE TABLE [qte].[SpotWeight]
(
[SpotWeightHdrID] [int] NOT NULL,
[AnnuityAccumMonth] [int] NOT NULL,
[Weight1] [float] NOT NULL,
[Weight2] [float] NOT NULL
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_SpotWeight] on [qte].[SpotWeight]'
GO
ALTER TABLE [qte].[SpotWeight] ADD CONSTRAINT [PK_SpotWeight] PRIMARY KEY CLUSTERED  ([SpotWeightHdrID], [AnnuityAccumMonth])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [qte].[SpotRate]'
GO
CREATE TABLE [qte].[SpotRate]
(
[SpotRateHdrID] [int] NOT NULL,
[AnnuityYear] [int] NOT NULL,
[SpotRate] [decimal] (19, 17) NOT NULL
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_SpotRate_1] on [qte].[SpotRate]'
GO
ALTER TABLE [qte].[SpotRate] ADD CONSTRAINT [PK_SpotRate_1] PRIMARY KEY CLUSTERED  ([SpotRateHdrID], [AnnuityYear])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [qte].[SpotInterest]'
GO
CREATE TABLE [qte].[SpotInterest]
(
[RateVersionID] [int] NOT NULL,
[AnnuityAccumMonth] [int] NOT NULL,
[AnnuityYear] [int] NOT NULL,
[AnnuityMonth] [int] NOT NULL,
[DiscountRate] [float] NULL,
[SpotInterestVx] [float] NULL
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_SpotInterest] on [qte].[SpotInterest]'
GO
ALTER TABLE [qte].[SpotInterest] ADD CONSTRAINT [PK_SpotInterest] PRIMARY KEY CLUSTERED  ([RateVersionID], [AnnuityAccumMonth])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [qte].[LifeExpMultiple]'
GO
CREATE TABLE [qte].[LifeExpMultiple]
(
[AnnuitantID] [int] NOT NULL,
[AnnuityYear] [int] NOT NULL,
[UseImprovement] [bit] NOT NULL,
[LifeExpMultipleQx] [float] NOT NULL,
[LifeExpMultipleS] [float] NULL
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_MultipleTable] on [qte].[LifeExpMultiple]'
GO
ALTER TABLE [qte].[LifeExpMultiple] ADD CONSTRAINT [PK_MultipleTable] PRIMARY KEY CLUSTERED  ([AnnuitantID], [AnnuityYear], [UseImprovement])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [qte].[BenefitQuote]'
GO
CREATE TABLE [qte].[BenefitQuote]
(
[BenefitQuoteID] [int] NOT NULL IDENTITY(1, 1),
[QuoteID] [int] NOT NULL,
[BenefitID] [int] NOT NULL,
[PrimaryAnnuitantID] [int] NOT NULL,
[JointAnnuitantID] [int] NOT NULL,
[PaymentMode] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[BenefitAmt] [decimal] (18, 2) NULL,
[PremiumAmt] [decimal] (18, 2) NULL,
[FirstPaymentDate] [date] NOT NULL,
[CertainYears] [int] NOT NULL,
[CertainMonths] [int] NOT NULL,
[ImprovementPct] [decimal] (5, 2) NOT NULL,
[EndDate] [date] NULL
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_BenefitQuote] on [qte].[BenefitQuote]'
GO
ALTER TABLE [qte].[BenefitQuote] ADD CONSTRAINT [PK_BenefitQuote] PRIMARY KEY CLUSTERED  ([BenefitQuoteID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [qte].[PaymentStream]'
GO
CREATE TABLE [qte].[PaymentStream]
(
[PaymentStreamID] [int] NOT NULL IDENTITY(1, 1),
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
[BenefitAmt] [decimal] (18, 2) NULL
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_PaymentStream] on [qte].[PaymentStream]'
GO
ALTER TABLE [qte].[PaymentStream] ADD CONSTRAINT [PK_PaymentStream] PRIMARY KEY CLUSTERED  ([PaymentStreamID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating index [IX_PaymentStream_BenefitQuoteID] on [qte].[PaymentStream]'
GO
CREATE NONCLUSTERED INDEX [IX_PaymentStream_BenefitQuoteID] ON [qte].[PaymentStream] ([BenefitQuoteID]) INCLUDE ([PaymentStreamID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [qte].[Benefit]'
GO
CREATE TABLE [qte].[Benefit]
(
[BenefitID] [int] NOT NULL IDENTITY(1, 1),
[BenefitDescr] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[UseJointAnnuitant] [bit] NOT NULL,
[DropDownOrder] [int] NOT NULL
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_Benefit] on [qte].[Benefit]'
GO
ALTER TABLE [qte].[Benefit] ADD CONSTRAINT [PK_Benefit] PRIMARY KEY CLUSTERED  ([BenefitID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding constraints to [qte].[Benefit]'
GO
ALTER TABLE [qte].[Benefit] ADD CONSTRAINT [IX_Benefit_BenefitDescr] UNIQUE NONCLUSTERED  ([BenefitDescr])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating index [IX_Benefit_DropDownOrder] on [qte].[Benefit]'
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_Benefit_DropDownOrder] ON [qte].[Benefit] ([DropDownOrder])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [qte].[Annuitant]'
GO
CREATE TABLE [qte].[Annuitant]
(
[AnnuitantID] [int] NOT NULL IDENTITY(1, 1),
[QuoteID] [int] NOT NULL,
[FirstName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[LastName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DOB] [date] NOT NULL,
[RatedAge] [int] NOT NULL,
[Gender] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_Annuitant] on [qte].[Annuitant]'
GO
ALTER TABLE [qte].[Annuitant] ADD CONSTRAINT [PK_Annuitant] PRIMARY KEY CLUSTERED  ([AnnuitantID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding constraints to [qte].[Annuitant]'
GO
ALTER TABLE [qte].[Annuitant] ADD CONSTRAINT [IX_Annuitant_QuoteFirstLast] UNIQUE NONCLUSTERED  ([QuoteID], [FirstName], [LastName])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [qte].[StlmtBroker]'
GO
CREATE TABLE [qte].[StlmtBroker]
(
[StlmtBrokerID] [int] NOT NULL IDENTITY(1, 1),
[FirstName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[MiddleInitial] [char] (1) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[LastName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[EntityName] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AddrLine1] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[AddrLine2] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[AddrLine3] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[City] [varchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[StateCode] [char] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[ZipCode5] [char] (5) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[PhoneNum] [char] (10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_StlmtBroker] on [qte].[StlmtBroker]'
GO
ALTER TABLE [qte].[StlmtBroker] ADD CONSTRAINT [PK_StlmtBroker] PRIMARY KEY CLUSTERED  ([StlmtBrokerID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [qte].[SpotRateHdr]'
GO
CREATE TABLE [qte].[SpotRateHdr]
(
[SpotRateHdrID] [int] NOT NULL IDENTITY(1, 1),
[SpotRateDescr] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateCreated] [datetime2] NOT NULL CONSTRAINT [DF_SpotRateHdr_DateCreated] DEFAULT (sysdatetime())
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_SpotRateHdr] on [qte].[SpotRateHdr]'
GO
ALTER TABLE [qte].[SpotRateHdr] ADD CONSTRAINT [PK_SpotRateHdr] PRIMARY KEY CLUSTERED  ([SpotRateHdrID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating index [IX_SpotRateHdr_Descr] on [qte].[SpotRateHdr]'
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_SpotRateHdr_Descr] ON [qte].[SpotRateHdr] ([SpotRateDescr])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [qte].[SpotWeightHdr]'
GO
CREATE TABLE [qte].[SpotWeightHdr]
(
[SpotWeightHdrID] [int] NOT NULL IDENTITY(1, 1),
[SpotWeightDescr] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[DateCreated] [datetime2] NOT NULL CONSTRAINT [DF_SpotWeightHdr_DateCreated] DEFAULT (sysdatetime())
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_SpotWeightHdr] on [qte].[SpotWeightHdr]'
GO
ALTER TABLE [qte].[SpotWeightHdr] ADD CONSTRAINT [PK_SpotWeightHdr] PRIMARY KEY CLUSTERED  ([SpotWeightHdrID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [qte].[StateCode]'
GO
CREATE TABLE [qte].[StateCode]
(
[StateCode] [char] (2) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[StateName] [varchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_StateCode] on [qte].[StateCode]'
GO
ALTER TABLE [qte].[StateCode] ADD CONSTRAINT [PK_StateCode] PRIMARY KEY CLUSTERED  ([StateCode])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating [qte].[NumbersTable]'
GO
CREATE TABLE [qte].[NumbersTable]
(
[Number] [int] NOT NULL IDENTITY(1, 1)
)
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating primary key [PK_NumbersTable] on [qte].[NumbersTable]'
GO
ALTER TABLE [qte].[NumbersTable] ADD CONSTRAINT [PK_NumbersTable] PRIMARY KEY CLUSTERED  ([Number])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding constraints to [qte].[Annuitant]'
GO
ALTER TABLE [qte].[Annuitant] ADD CONSTRAINT [CK_Annuitant_RatedAge] CHECK (([RatedAge]>=(0) AND [RatedAge]<=(99)))
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
ALTER TABLE [qte].[Annuitant] ADD CONSTRAINT [CK_Annuitant_Gender] CHECK (([Gender]='F' OR [Gender]='M'))
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding constraints to [qte].[Mortality]'
GO
ALTER TABLE [qte].[Mortality] ADD CONSTRAINT [CK_Mortality_Gender] CHECK (([Gender]='F' OR [Gender]='M'))
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [qte].[BenefitQuote]'
GO
ALTER TABLE [qte].[BenefitQuote] ADD CONSTRAINT [FK_BenefitQuote_JointAnnuitant] FOREIGN KEY ([JointAnnuitantID]) REFERENCES [qte].[Annuitant] ([AnnuitantID])
GO
ALTER TABLE [qte].[BenefitQuote] ADD CONSTRAINT [FK_BenefitQuote_PrimaryAnnuitant] FOREIGN KEY ([PrimaryAnnuitantID]) REFERENCES [qte].[Annuitant] ([AnnuitantID])
GO
ALTER TABLE [qte].[BenefitQuote] ADD CONSTRAINT [FK_BenefitQuote_Quote] FOREIGN KEY ([QuoteID]) REFERENCES [qte].[Quote] ([QuoteID])
GO
ALTER TABLE [qte].[BenefitQuote] ADD CONSTRAINT [FK_BenefitQuote_Benefit] FOREIGN KEY ([BenefitID]) REFERENCES [qte].[Benefit] ([BenefitID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [qte].[LifeExpMultiple]'
GO
ALTER TABLE [qte].[LifeExpMultiple] ADD CONSTRAINT [FK_LifeExpMultiple_Annuitant] FOREIGN KEY ([AnnuitantID]) REFERENCES [qte].[Annuitant] ([AnnuitantID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [qte].[Annuitant]'
GO
ALTER TABLE [qte].[Annuitant] ADD CONSTRAINT [FK_Annuitant_Quote] FOREIGN KEY ([QuoteID]) REFERENCES [qte].[Quote] ([QuoteID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [qte].[PaymentStream]'
GO
ALTER TABLE [qte].[PaymentStream] ADD CONSTRAINT [FK_PaymentStream_BenefitQuote] FOREIGN KEY ([BenefitQuoteID]) REFERENCES [qte].[BenefitQuote] ([BenefitQuoteID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [qte].[RateVersion]'
GO
ALTER TABLE [qte].[RateVersion] ADD CONSTRAINT [FK_RateVersion_Improvement] FOREIGN KEY ([ImprovementID]) REFERENCES [qte].[Improvement] ([ImprovementID])
GO
ALTER TABLE [qte].[RateVersion] ADD CONSTRAINT [FK_RateVersion_MortalityHdr] FOREIGN KEY ([MortalityHdrID]) REFERENCES [qte].[MortalityHdr] ([MortalityHdrID])
GO
ALTER TABLE [qte].[RateVersion] ADD CONSTRAINT [FK_RateVersion_SpotRateHdr] FOREIGN KEY ([SpotRateHdrID]) REFERENCES [qte].[SpotRateHdr] ([SpotRateHdrID])
GO
ALTER TABLE [qte].[RateVersion] ADD CONSTRAINT [FK_RateVersion_SpotWeightHdr] FOREIGN KEY ([SpotWeightHdrID]) REFERENCES [qte].[SpotWeightHdr] ([SpotWeightHdrID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [qte].[Mortality]'
GO
ALTER TABLE [qte].[Mortality] ADD CONSTRAINT [FK_Mortality_MortalityHdr] FOREIGN KEY ([MortalityHdrID]) REFERENCES [qte].[MortalityHdr] ([MortalityHdrID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [qte].[Quote]'
GO
ALTER TABLE [qte].[Quote] ADD CONSTRAINT [FK_Quote_RateVersion] FOREIGN KEY ([RateVersionID]) REFERENCES [qte].[RateVersion] ([RateVersionID])
GO
ALTER TABLE [qte].[Quote] ADD CONSTRAINT [FK_Quote_StlmtBroker] FOREIGN KEY ([StlmtBrokerID]) REFERENCES [qte].[StlmtBroker] ([StlmtBrokerID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [qte].[SpotInterest]'
GO
ALTER TABLE [qte].[SpotInterest] ADD CONSTRAINT [FK_SpotInterest_RateVersion] FOREIGN KEY ([RateVersionID]) REFERENCES [qte].[RateVersion] ([RateVersionID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [qte].[SpotRate]'
GO
ALTER TABLE [qte].[SpotRate] ADD CONSTRAINT [FK_SpotRate_SpotRateHdr] FOREIGN KEY ([SpotRateHdrID]) REFERENCES [qte].[SpotRateHdr] ([SpotRateHdrID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [qte].[SpotWeight]'
GO
ALTER TABLE [qte].[SpotWeight] ADD CONSTRAINT [FK_SpotWeight_SpotWeightHdr] FOREIGN KEY ([SpotWeightHdrID]) REFERENCES [qte].[SpotWeightHdr] ([SpotWeightHdrID])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Adding foreign keys to [qte].[StlmtBroker]'
GO
ALTER TABLE [qte].[StlmtBroker] ADD CONSTRAINT [FK_StlmtBroker_StateCode] FOREIGN KEY ([StateCode]) REFERENCES [qte].[StateCode] ([StateCode])
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
PRINT N'Creating extended properties'
GO
EXEC sp_addextendedproperty N'MS_Description', N'Gender must be either ''M'' or ''F''.', 'SCHEMA', N'qte', 'TABLE', N'Mortality', 'CONSTRAINT', N'CK_Mortality_Gender'
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
COMMIT TRANSACTION
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
DECLARE @Success AS BIT
SET @Success = 1
SET NOEXEC OFF
IF (@Success = 1) PRINT 'The database update succeeded'
ELSE BEGIN
	IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
	PRINT 'The database update failed'
END
GO
