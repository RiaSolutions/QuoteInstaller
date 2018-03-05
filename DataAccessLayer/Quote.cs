using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.Configuration;
using System.Data.SqlClient;
using System.Data;

namespace DataAccessLayer
{
    public class Quote
    {
        private static String GetConnectionString()
        {
            return ConfigurationManager.ConnectionStrings["DefaultConnection"].ToString();
        }

        public int SaveQuote(int quoteID, int brokerID, int rateVersionID, DateTime purchaseDate, decimal budgetAmt)
        {
            int newQuoteID;

            String strConnString = GetConnectionString();
            SqlConnection conn = new SqlConnection(strConnString);
            SqlCommand cmd = new SqlCommand("qte.uspUpsertQuote", conn);
            cmd.CommandType = System.Data.CommandType.StoredProcedure;

            SqlParameter returnvalue = new SqlParameter("@RETURN_VALUE", System.Data.SqlDbType.Int);
            returnvalue.Direction = System.Data.ParameterDirection.ReturnValue;
            cmd.Parameters.Add(returnvalue);

            SqlParameter spQuoteID = new SqlParameter("@QuoteID", System.Data.SqlDbType.Int);
            spQuoteID.Direction = System.Data.ParameterDirection.Input;
            spQuoteID.Value = quoteID;
            cmd.Parameters.Add(spQuoteID);

            SqlParameter spStlmtBrokerID = new SqlParameter("@StlmtBrokerID", System.Data.SqlDbType.Int);
            spStlmtBrokerID.Direction = System.Data.ParameterDirection.Input;
            spStlmtBrokerID.Value = brokerID;
            cmd.Parameters.Add(spStlmtBrokerID);

            SqlParameter spRateVersionID = new SqlParameter("@RateVersionID", System.Data.SqlDbType.Int);
            spRateVersionID.Direction = System.Data.ParameterDirection.Input;
            spRateVersionID.Value = rateVersionID;
            cmd.Parameters.Add(spRateVersionID);

            SqlParameter spPurchaseDate = new SqlParameter("@PurchaseDate", System.Data.SqlDbType.Date);
            spPurchaseDate.Direction = System.Data.ParameterDirection.Input;
            spPurchaseDate.Value = purchaseDate;
            cmd.Parameters.Add(spPurchaseDate);

            SqlParameter spBudgetAmt = new SqlParameter("@BudgetAmt", System.Data.SqlDbType.Decimal);
            spBudgetAmt.Direction = System.Data.ParameterDirection.Input;
            spBudgetAmt.Precision = 19;
            spBudgetAmt.Scale = 3;
            spBudgetAmt.Value = budgetAmt;
            cmd.Parameters.Add(spBudgetAmt);

            SqlParameter spNewQuoteID = new SqlParameter("@NewQuoteID", System.Data.SqlDbType.Int);
            spNewQuoteID.Direction = System.Data.ParameterDirection.Output;
            cmd.Parameters.Add(spNewQuoteID);

            try
            {
                conn.Open();
                cmd.ExecuteNonQuery();

                if ((int)cmd.Parameters["@RETURN_VALUE"].Value == 0)
                    newQuoteID = (int)cmd.Parameters["@NewQuoteID"].Value;
                else
                    newQuoteID = 0;

                return newQuoteID;

            }

            catch (Exception ex)
            {
                throw ex;
            }

            finally
            {
                conn.Close();
                conn.Dispose();
            }

        }
    }
}
