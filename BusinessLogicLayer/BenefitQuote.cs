using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

//using System.Configuration;
//using System.Data.SqlClient;
using System.Data;

namespace BusinessLogicLayer
{
    public class BenefitQuote
    {
        private int _benefitQuoteID;
        private int _quoteID;
        private int _benefitID;
        private int _primaryAnnuitantID;
        private int _jointAnnuitantID;
        private Char _paymentMode;
        private decimal _benefitAmt;
        private decimal _premiumAmt;
        private double _paymentValueAmt;
        private DateTime _firstPaymentDate;
        private int _certainYears;
        private int _certainMonths;
        private decimal _improvementPct;
        private DateTime _endDate;
        
        public int BenefitQuoteID
        {
            get { return _benefitQuoteID; }
            set { _benefitQuoteID = value; }
        }
        public int QuoteID
        {
            get { return _quoteID; }
            set { _quoteID = value; }
        }
        public int BenefitID
        {
            get { return _benefitID; }
            set { _benefitID = value; }
        }
        public int PrimaryAnnuitantID
        {
            get { return _primaryAnnuitantID; }
            set { _primaryAnnuitantID = value; }
        }
        public int JointAnnuitantID
        {
            get { return _jointAnnuitantID; }
            set { _jointAnnuitantID = value; }
        }
        public Char PaymentMode
        {
            get { return _paymentMode; }
            set { _paymentMode = value; }
        }
        public decimal BenefitAmt
        {
            get { return _benefitAmt; }
            set { _benefitAmt = value; }
        }
        public decimal PremiumAmt
        {
            get { return _premiumAmt; }
            set { _premiumAmt = value; }
        }
        public double PaymentValueAmt
        {
            get { return _paymentValueAmt; }
            set { _paymentValueAmt = value; }
        }
        public DateTime FirstPaymentDate
        {
            get { return _firstPaymentDate; }
            set { _firstPaymentDate = value; }
        }
        public int CertainYears
        {
            get { return _certainYears; }
            set { _certainYears = value; }
        }
        public int CertainMonths
        {
            get { return _certainMonths; }
            set { _certainMonths = value; }
        }
        public decimal ImprovementPct
        {
            get { return _improvementPct; }
            set { _improvementPct = value; }
        }
        public DateTime EndDate
        {
            get { return _endDate; }
            set { _endDate = value; }
        }
        public BenefitQuote()
        {
            BenefitQuoteID = 0;
            QuoteID = 0;
            BenefitID = 0;
            PrimaryAnnuitantID = 0;
            JointAnnuitantID = 0;
            PaymentMode = ' ';
            BenefitAmt = 0.0m;
            PremiumAmt = 0.0m;
            PaymentValueAmt = 0.0f;
            FirstPaymentDate = Convert.ToDateTime("1/1/0001");
            CertainYears = 0;
            CertainMonths = 0;
            ImprovementPct = 0.0m;
            EndDate = Convert.ToDateTime("1/1/0001");
        }
        public void SaveBenefitQuote(int benefitQuoteID, int quoteID, int benefitID, int primaryAnnuitantID, int jointAnnuitantID, Char paymentMode
            , decimal benefitAmt
            , decimal premiumAmt, DateTime firstPaymentDate, int certainYears, int certainMonths, decimal improvementPct, DateTime endDate
            , Boolean persist)
        {
            DataAccessLayer.BenefitQuote bq = new DataAccessLayer.BenefitQuote();

            decimal finalPremiumAmt = 0.0m;
            decimal finalBenefitAmt = 0.0m;
            double finalPaymentValueAmt = 0.0f;

            //if (benefitAmt > 0.0m)
            //    premiumAmt = 0.0m;
            if (premiumAmt > 0.0m)
                benefitAmt = 0.0m;

            bq.SaveBenefitQuote(benefitQuoteID, quoteID, benefitID, primaryAnnuitantID, jointAnnuitantID, paymentMode, benefitAmt,
                premiumAmt, firstPaymentDate, certainYears, certainMonths, improvementPct, endDate, persist, ref finalPremiumAmt, ref finalBenefitAmt,
                ref finalPaymentValueAmt);

            BenefitQuoteID = benefitQuoteID;
            QuoteID = quoteID;
            BenefitID = benefitID;
            PrimaryAnnuitantID = primaryAnnuitantID;
            JointAnnuitantID = jointAnnuitantID;
            PaymentMode = paymentMode;
            BenefitAmt = finalBenefitAmt;
            PremiumAmt = finalPremiumAmt;
            PaymentValueAmt = finalPaymentValueAmt;
            FirstPaymentDate = firstPaymentDate;
            CertainYears = certainYears;
            CertainMonths = certainMonths;
            ImprovementPct = improvementPct;
            EndDate = endDate;
        }

        public void FillBenefitQuoteDataGrid(ref DataTable dt, int quoteID)
        {
            DataAccessLayer.BenefitQuote bq = new DataAccessLayer.BenefitQuote();
            bq.FillBenefitQuoteDataGrid(ref dt, quoteID);
        }

        public void DeleteBenefitQuote(int benefitQuoteID)
        {
            DataAccessLayer.BenefitQuote bq = new DataAccessLayer.BenefitQuote();
            bq.DeleteBenefitQuote(benefitQuoteID);
        }

        public void GetBenefitQuote(int benefitQuoteID)
        {
            DataAccessLayer.BenefitQuote dbq = new DataAccessLayer.BenefitQuote();

            int tmpBenefitID = 0;
            int tmpPrimaryAnnuitantID = 0;
            int tmpJointAnnuitantID = 0;
            Char tmpPaymentMode = ' ';
            decimal tmpBenefitAmt = 0.0m;
            decimal tmpPremiumAmt = 0.0m;
            DateTime tmpFirstPaymentDate = Convert.ToDateTime("1/1/0001");
            int tmpCertainYears = 0;
            int tmpCertainMonths = 0;
            decimal tmpImprovementPct = 0.0m;
            DateTime tmpEndDate = Convert.ToDateTime("1/1/0001");

            dbq.GetBenefitQuote(benefitQuoteID, ref tmpBenefitID, ref tmpPrimaryAnnuitantID, ref tmpJointAnnuitantID, ref tmpPaymentMode,
            ref tmpBenefitAmt, ref tmpPremiumAmt, ref tmpFirstPaymentDate, ref tmpCertainYears, ref tmpCertainMonths,
            ref tmpImprovementPct, ref tmpEndDate);

            BenefitID = tmpBenefitID;
            PrimaryAnnuitantID = tmpPrimaryAnnuitantID;
            JointAnnuitantID = tmpJointAnnuitantID;
            PaymentMode = tmpPaymentMode;
            BenefitAmt = tmpBenefitAmt;
            PremiumAmt = tmpPremiumAmt;
            FirstPaymentDate = tmpFirstPaymentDate;
            CertainYears = tmpCertainYears;
            CertainMonths = tmpCertainMonths;
            ImprovementPct = tmpImprovementPct;
            EndDate = tmpEndDate;

        }

    }
}
