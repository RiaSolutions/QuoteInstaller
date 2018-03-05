using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.Data.SqlClient;
using System.Data;
using System.Configuration;

namespace DataAccessLayer
{
    public class Report
    {
        private static String GetConnectionString()
        {
            return ConfigurationManager.ConnectionStrings["DefaultConnection"].ToString();
        }
        public void CreateSettlementReportData(int quoteID, ref decimal irr, ref decimal equivalentCash)
        {

            String strConnString = GetConnectionString();
            SqlConnection conn = new SqlConnection(strConnString);
            SqlCommand cmd = new SqlCommand("qte.uspCreateSettlementProposal_Seq", conn);
            cmd.CommandType = System.Data.CommandType.StoredProcedure;

            SqlParameter returnvalue = new SqlParameter("@RETURN_VALUE", System.Data.SqlDbType.Int);
            returnvalue.Direction = System.Data.ParameterDirection.ReturnValue;
            cmd.Parameters.Add(returnvalue);

            SqlParameter spQuoteID = new SqlParameter("@QuoteID", System.Data.SqlDbType.Int);
            spQuoteID.Direction = System.Data.ParameterDirection.Input;
            spQuoteID.Value = quoteID;
            cmd.Parameters.Add(spQuoteID);

            SqlParameter spIRR = new SqlParameter("@IRR", System.Data.SqlDbType.Decimal);
            spIRR.Direction = System.Data.ParameterDirection.Output;
            spIRR.Precision = 19;
            spIRR.Scale = 4;
            cmd.Parameters.Add(spIRR);

            SqlParameter spEquivalentCash = new SqlParameter("@EquivalentCash", System.Data.SqlDbType.Decimal);
            spEquivalentCash.Direction = System.Data.ParameterDirection.Output;
            spEquivalentCash.Precision = 19;
            spEquivalentCash.Scale = 2;
            cmd.Parameters.Add(spEquivalentCash);

            try
            {
                conn.Open();
                cmd.ExecuteNonQuery();

                if ((int)cmd.Parameters["@RETURN_VALUE"].Value == 0)
                {
                    irr = (decimal)cmd.Parameters["@IRR"].Value;
                    equivalentCash = (decimal)cmd.Parameters["@EquivalentCash"].Value;
                }
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
