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
    public class BenefitQuote
    {
        private static String GetConnectionString()
        {
            return ConfigurationManager.ConnectionStrings["DefaultConnection"].ToString();
        }
        public void FillBenefitQuoteDataGrid(ref DataTable dt, int quoteID)
        {
            string ConString = GetConnectionString();
            string CmdString = string.Empty;
            using (SqlConnection con = new SqlConnection(ConString))
            {
                SqlCommand cmd = new SqlCommand("qte.uspGetBenefitQuoteGrid", con);
                cmd.Parameters.AddWithValue("@QuoteID", quoteID);
                cmd.CommandType = CommandType.StoredProcedure;
                SqlDataAdapter sda = new SqlDataAdapter();
                sda.SelectCommand = cmd;
                //dt = new DataTable("BenefitQuote");
                sda.Fill(dt);

                //CmdString = "SELECT bq.BenefitQuoteID, a.FirstName + ' ' + a.LastName AS AnnuitantName, b.BenefitDescr, bq.BenefitAmt, bq.PremiumAmt FROM qte.BenefitQuote bq INNER JOIN qte.Annuitant a ON a.AnnuitantID = bq.PrimaryAnnuitantID INNER JOIN qte.Benefit b ON b.BenefitID = bq.BenefitID and bq.QuoteID = " + Convert.ToString(quoteID);
                ////SqlCommand cmd = new SqlCommand(CmdString, con);
                //SqlCommand cmd = new SqlCommand(CmdString, con);
                //SqlDataAdapter sda = new SqlDataAdapter(cmd);
                //dt = new DataTable("BenefitQuote");
                //sda.Fill(dt);
            }
        }

        public void DeleteBenefitQuote(int benefitQuoteID)
        {
            String strConnString = GetConnectionString();
            SqlConnection conn = new SqlConnection(strConnString);
            SqlCommand cmd = new SqlCommand("qte.uspDeleteBenefitQuote", conn);
            cmd.CommandType = System.Data.CommandType.StoredProcedure;

            SqlParameter returnvalue = new SqlParameter("@RETURN_VALUE", System.Data.SqlDbType.Int);
            returnvalue.Direction = System.Data.ParameterDirection.ReturnValue;
            cmd.Parameters.Add(returnvalue);

            SqlParameter spBenefitQuoteID = new SqlParameter("@BenefitQuoteID", System.Data.SqlDbType.Int);
            spBenefitQuoteID.Direction = System.Data.ParameterDirection.Input;
            spBenefitQuoteID.Value = benefitQuoteID;
            cmd.Parameters.Add(spBenefitQuoteID);

            try
            {
                conn.Open();
                cmd.ExecuteNonQuery();
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

        public void SaveBenefitQuote(int benefitQuoteID, int quoteID, int benefitID, int primaryAnnuitantID, int jointAnnuitantID, Char paymentMode, decimal benefitAmt,
            decimal premiumAmt, DateTime firstPaymentDate, int certainYears, int certainMonths, decimal improvementPct, DateTime endDate, Boolean persist
            , ref decimal finalPremiumAmt
            , ref decimal finalBenefitAmt, ref double finalPaymentValueAmt)
        {

            String strConnString = GetConnectionString();
            SqlConnection conn = new SqlConnection(strConnString);
            SqlCommand cmd = new SqlCommand("qte.uspUpsertBenefitQuote", conn);
            cmd.CommandType = System.Data.CommandType.StoredProcedure;

            SqlParameter returnvalue = new SqlParameter("@RETURN_VALUE", System.Data.SqlDbType.Int);
            returnvalue.Direction = System.Data.ParameterDirection.ReturnValue;
            cmd.Parameters.Add(returnvalue);

            SqlParameter spBenefitQuoteID = new SqlParameter("@BenefitQuoteID", System.Data.SqlDbType.Int);
            spBenefitQuoteID.Direction = System.Data.ParameterDirection.Input;
            spBenefitQuoteID.Value = benefitQuoteID;
            cmd.Parameters.Add(spBenefitQuoteID);

            SqlParameter spQuoteID = new SqlParameter("@QuoteID", System.Data.SqlDbType.Int);
            spQuoteID.Direction = System.Data.ParameterDirection.Input;
            spQuoteID.Value = quoteID;
            cmd.Parameters.Add(spQuoteID);

            SqlParameter spBenefitID = new SqlParameter("@BenefitID", System.Data.SqlDbType.Int);
            spBenefitID.Direction = System.Data.ParameterDirection.Input;
            spBenefitID.Value = benefitID;
            cmd.Parameters.Add(spBenefitID);

            SqlParameter spPrimaryAnnuitantID = new SqlParameter("@PrimaryAnnuitantID", System.Data.SqlDbType.Int);
            spPrimaryAnnuitantID.Direction = System.Data.ParameterDirection.Input;
            spPrimaryAnnuitantID.Value = primaryAnnuitantID;
            cmd.Parameters.Add(spPrimaryAnnuitantID);

            SqlParameter spJointAnnuitantID = new SqlParameter("@JointAnnuitantID", System.Data.SqlDbType.Int);
            spJointAnnuitantID.Direction = System.Data.ParameterDirection.Input;
            spJointAnnuitantID.Value = jointAnnuitantID;
            cmd.Parameters.Add(spJointAnnuitantID);

            SqlParameter spPaymentMode = new SqlParameter("@PaymentMode", System.Data.SqlDbType.Char);
            spPaymentMode.Direction = System.Data.ParameterDirection.Input;
            spPaymentMode.Size = 1;
            spPaymentMode.Value = paymentMode;
            cmd.Parameters.Add(spPaymentMode);

            SqlParameter spBenefitAmt = new SqlParameter("@BenefitAmt", System.Data.SqlDbType.Decimal);
            spBenefitAmt.Direction = System.Data.ParameterDirection.Input;
            spBenefitAmt.Precision = 18;
            spBenefitAmt.Scale = 2;
            spBenefitAmt.Value = benefitAmt;
            cmd.Parameters.Add(spBenefitAmt);

            SqlParameter spPremiumAmt = new SqlParameter("@PremiumAmt", System.Data.SqlDbType.Decimal);
            spPremiumAmt.Direction = System.Data.ParameterDirection.Input;
            spPremiumAmt.Precision = 18;
            spPremiumAmt.Scale = 2;
            spPremiumAmt.Value = premiumAmt;
            cmd.Parameters.Add(spPremiumAmt);

            SqlParameter spFirstPaymentDate = new SqlParameter("@FirstPaymentDate", System.Data.SqlDbType.Date);
            spFirstPaymentDate.Direction = System.Data.ParameterDirection.Input;
            spFirstPaymentDate.Value = firstPaymentDate;
            cmd.Parameters.Add(spFirstPaymentDate);

            SqlParameter spCertainYears = new SqlParameter("@CertainYears", System.Data.SqlDbType.Int);
            spCertainYears.Direction = System.Data.ParameterDirection.Input;
            spCertainYears.Value = certainYears;
            cmd.Parameters.Add(spCertainYears);

            SqlParameter spCertainMonths = new SqlParameter("@CertainMonths", System.Data.SqlDbType.Int);
            spCertainMonths.Direction = System.Data.ParameterDirection.Input;
            spCertainMonths.Value = certainMonths;
            cmd.Parameters.Add(spCertainMonths);

            SqlParameter spImprovementPct = new SqlParameter("@ImprovementPct", System.Data.SqlDbType.Decimal);
            spImprovementPct.Direction = System.Data.ParameterDirection.Input;
            spImprovementPct.Precision = 5;
            spImprovementPct.Scale = 2;
            spImprovementPct.Value = improvementPct;
            cmd.Parameters.Add(spImprovementPct);

            SqlParameter spEndDate = new SqlParameter("@EndDate", System.Data.SqlDbType.Date);
            spEndDate.Direction = System.Data.ParameterDirection.Input;
            spEndDate.Value = endDate;
            cmd.Parameters.Add(spEndDate);

            SqlParameter spPersist = new SqlParameter("@Persist", System.Data.SqlDbType.Bit);
            spPersist.Direction = System.Data.ParameterDirection.Input;
            spPersist.Value = persist;
            cmd.Parameters.Add(spPersist);

            SqlParameter spFinalPremiumAmt = new SqlParameter("@FinalPremiumAmt", System.Data.SqlDbType.Decimal);
            spFinalPremiumAmt.Direction = System.Data.ParameterDirection.Output;
            spFinalPremiumAmt.Precision = 18;
            spFinalPremiumAmt.Scale = 2;
            cmd.Parameters.Add(spFinalPremiumAmt);

            SqlParameter spFinalBenefitAmt = new SqlParameter("@FinalBenefitAmt", System.Data.SqlDbType.Decimal);
            spFinalBenefitAmt.Direction = System.Data.ParameterDirection.Output;
            spFinalBenefitAmt.Precision = 18;
            spFinalBenefitAmt.Scale = 2;
            cmd.Parameters.Add(spFinalBenefitAmt);

            SqlParameter spFinalPaymentValueAmt = new SqlParameter("@FinalPaymentValueAmt", System.Data.SqlDbType.Float);
            spFinalPaymentValueAmt.Direction = System.Data.ParameterDirection.Output;
            cmd.Parameters.Add(spFinalPaymentValueAmt);

            try
            {
                conn.Open();
                cmd.ExecuteNonQuery();

                if ((int)cmd.Parameters["@RETURN_VALUE"].Value == 0)
                {
                    finalPremiumAmt = (decimal)cmd.Parameters["@FinalPremiumAmt"].Value;
                    finalBenefitAmt = (decimal)cmd.Parameters["@FinalBenefitAmt"].Value;
                    finalPaymentValueAmt = (double)cmd.Parameters["@FinalPaymentValueAmt"].Value;
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
        public void GetBenefitQuote(int benefitQuoteID, ref int benefitID, ref int primaryAnnuitantID, ref int jointAnnuitantID, ref char paymentMode,
            ref decimal benefitAmt, ref decimal premiumAmt, ref DateTime firstPaymentDate, ref int certainYears, ref int certainMonths,
            ref decimal improvementPct, ref DateTime endDate)
        {

            String strConnString = GetConnectionString();
            SqlConnection conn = new SqlConnection(strConnString);
            SqlCommand cmd = new SqlCommand("qte.uspGetBenefitQuote", conn);
            cmd.CommandType = System.Data.CommandType.StoredProcedure;

            SqlParameter returnvalue = new SqlParameter("@RETURN_VALUE", System.Data.SqlDbType.Int);
            returnvalue.Direction = System.Data.ParameterDirection.ReturnValue;
            cmd.Parameters.Add(returnvalue);

            SqlParameter spBenefitQuoteID = new SqlParameter("@BenefitQuoteID", System.Data.SqlDbType.Int);
            spBenefitQuoteID.Direction = System.Data.ParameterDirection.Input;
            spBenefitQuoteID.Value = benefitQuoteID;
            cmd.Parameters.Add(spBenefitQuoteID);

            SqlParameter spBenefitID = new SqlParameter("@BenefitID", System.Data.SqlDbType.Int);
            spBenefitID.Direction = System.Data.ParameterDirection.Output;
            cmd.Parameters.Add(spBenefitID);

            SqlParameter spPrimaryAnnuitantID = new SqlParameter("@PrimaryAnnuitantID", System.Data.SqlDbType.Int);
            spPrimaryAnnuitantID.Direction = System.Data.ParameterDirection.Output;
            cmd.Parameters.Add(spPrimaryAnnuitantID);

            SqlParameter spJointAnnuitantID = new SqlParameter("@JointAnnuitantID", System.Data.SqlDbType.Int);
            spJointAnnuitantID.Direction = System.Data.ParameterDirection.Output;
            cmd.Parameters.Add(spJointAnnuitantID);

            SqlParameter spPaymentMode = new SqlParameter("@PaymentMode", System.Data.SqlDbType.Char);
            spPaymentMode.Direction = System.Data.ParameterDirection.Output;
            spPaymentMode.Size = 1;
            cmd.Parameters.Add(spPaymentMode);

            SqlParameter spBenefitAmt = new SqlParameter("@BenefitAmt", System.Data.SqlDbType.Decimal);
            spBenefitAmt.Direction = System.Data.ParameterDirection.Output;
            spBenefitAmt.Precision = 15;
            spBenefitAmt.Scale = 2;
            cmd.Parameters.Add(spBenefitAmt);

            SqlParameter spPremiumAmt = new SqlParameter("@PremiumAmt", System.Data.SqlDbType.Decimal);
            spPremiumAmt.Direction = System.Data.ParameterDirection.Output;
            spPremiumAmt.Precision = 18;
            spPremiumAmt.Scale = 2;
            cmd.Parameters.Add(spPremiumAmt);

            SqlParameter spFirstPaymentDate = new SqlParameter("@FirstPaymentDate", System.Data.SqlDbType.Date);
            spFirstPaymentDate.Direction = System.Data.ParameterDirection.Output;
            cmd.Parameters.Add(spFirstPaymentDate);

            SqlParameter spCertainYears = new SqlParameter("@CertainYears", System.Data.SqlDbType.Int);
            spCertainYears.Direction = System.Data.ParameterDirection.Output;
            cmd.Parameters.Add(spCertainYears);

            SqlParameter spCertainMonths = new SqlParameter("@CertainMonths", System.Data.SqlDbType.Int);
            spCertainMonths.Direction = System.Data.ParameterDirection.Output;
            cmd.Parameters.Add(spCertainMonths);

            SqlParameter spImprovementPct = new SqlParameter("@ImprovementPct", System.Data.SqlDbType.Decimal);
            spImprovementPct.Direction = System.Data.ParameterDirection.Output;
            spImprovementPct.Precision = 5;
            spImprovementPct.Scale = 2;
            cmd.Parameters.Add(spImprovementPct);

            SqlParameter spEndDate = new SqlParameter("@EndDate", System.Data.SqlDbType.Date);
            spEndDate.Direction = System.Data.ParameterDirection.Output;
            cmd.Parameters.Add(spEndDate);

            try
            {
                conn.Open();
                cmd.ExecuteNonQuery();

                if ((int)cmd.Parameters["@RETURN_VALUE"].Value == 0)
                {
                    benefitID = (int)cmd.Parameters["@BenefitID"].Value;
                    primaryAnnuitantID = (int)cmd.Parameters["@PrimaryAnnuitantID"].Value;
                    jointAnnuitantID = (int)cmd.Parameters["@JointAnnuitantID"].Value;
                    paymentMode = Convert.ToChar(cmd.Parameters["@PaymentMode"].Value);
                    benefitAmt = (decimal)cmd.Parameters["@BenefitAmt"].Value;
                    premiumAmt = (decimal)cmd.Parameters["@PremiumAmt"].Value;
                    firstPaymentDate = (DateTime)cmd.Parameters["@FirstPaymentDate"].Value;
                    certainYears = (int)cmd.Parameters["@CertainYears"].Value;
                    certainMonths = (int)cmd.Parameters["@CertainMonths"].Value;
                    improvementPct = (decimal)cmd.Parameters["@ImprovementPct"].Value;
                    endDate = (DateTime)cmd.Parameters["@EndDate"].Value;
                }
                else
                {
                    benefitID = 0;
                    primaryAnnuitantID = 0;
                    jointAnnuitantID = 0;
                    paymentMode = ' ';
                    benefitAmt = 0.0m;
                    premiumAmt = 0.0m;
                    firstPaymentDate = Convert.ToDateTime("1/1/0001");
                    certainYears = 0;
                    certainMonths = 0;
                    improvementPct = 0.0m;
                    endDate = Convert.ToDateTime("1/1/0001");
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
