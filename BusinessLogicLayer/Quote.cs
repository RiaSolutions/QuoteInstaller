using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using DataAccessLayer;

namespace BusinessLogicLayer
{
    public class Quote
    {
        private int _quoteID;
        private string _quoteDescr;
        private int _rateVersionID;
        private int _stlmntBrokerID;
        private DateTime _purchaseDate;
        private decimal _budgetAmt;

        public int QuoteID
        {
            get { return _quoteID; }
            set { _quoteID = value; }
        }
        public string QuoteDescr
        {
            get { return _quoteDescr; }
            set { _quoteDescr = value; }
        }
        public int RateVersionID
        {
            get { return _rateVersionID; }
            set { _rateVersionID = value; }
        }
        public int StlmntBrokerID
        {
            get { return _stlmntBrokerID; }
            set { _stlmntBrokerID = value; }
        }
        public DateTime PurchaseDate
        {
            get { return _purchaseDate; }
            set { _purchaseDate = value; }
        }
        public decimal BudgetAmt
        {
            get { return _budgetAmt; }
            set { _budgetAmt = value; }
        }

        public Quote()
        {
            QuoteID = 0;
            QuoteDescr = "";
            RateVersionID = 0;
            StlmntBrokerID = 0;
            PurchaseDate = Convert.ToDateTime("1/1/0001");
            BudgetAmt = 0.0m;
        }

        public int SaveQuote(int quoteID, int brokerID, int rateVersionID, DateTime purchaseDate, Decimal budgetAmt)
        {
            DataAccessLayer.Quote qte = new DataAccessLayer.Quote();
            QuoteID = qte.SaveQuote(quoteID, brokerID, rateVersionID, purchaseDate, budgetAmt);
            RateVersionID = rateVersionID;
            PurchaseDate = purchaseDate;
            BudgetAmt = budgetAmt;

            return QuoteID;
        }

    }
}
