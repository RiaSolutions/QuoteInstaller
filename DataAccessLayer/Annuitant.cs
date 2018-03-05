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
    public class Annuitant
    {
        private static String GetConnectionString()
        {
            return ConfigurationManager.ConnectionStrings["DefaultConnection"].ToString();
        }
        public void FillAnnuitantComboBox(ref SqlDataAdapter da, int quoteID)
        {
            //string ConString = GetConnectionString();
            //using (SqlConnection con = new SqlConnection(ConString))
            //{
            //    SqlCommand cmd = new SqlCommand("qte.uspGetAnnuitant", con);
            //    cmd.Parameters.AddWithValue("@QuoteID", quoteID);
            //    cmd.CommandType = CommandType.StoredProcedure;
            //    //SqlDataAdapter sda = new SqlDataAdapter();
            //    da.SelectCommand = cmd;
            //    DataTable dt = new DataTable("Annuitant");
            //    da.Fill(dt);
            //}

            String strConnString = GetConnectionString();
            SqlConnection conn = new SqlConnection(strConnString);
            da = new SqlDataAdapter(@"SELECT AnnuitantID, FirstName + ' ' + LastName AS AnnuitantName FROM qte.Annuitant WHERE QuoteID = '" + quoteID.ToString() + "' ORDER BY FirstName + ' ' + LastName", conn);

        }
        public void AddAnnuitant(int quoteID, int annuitantID, DateTime dob,
            string firstName, string lastName, int ratedAge, char gender)
        {

            String strConnString = GetConnectionString();
            SqlConnection conn = new SqlConnection(strConnString);
            SqlCommand cmd = new SqlCommand("qte.uspUpsertAnnuitant", conn);
            cmd.CommandType = System.Data.CommandType.StoredProcedure;


            SqlParameter returnvalue = new SqlParameter("@RETURN_VALUE", System.Data.SqlDbType.Int);
            returnvalue.Direction = System.Data.ParameterDirection.ReturnValue;
            cmd.Parameters.Add(returnvalue);

            SqlParameter spQuoteID = new SqlParameter("@QuoteID", System.Data.SqlDbType.Int);
            spQuoteID.Direction = System.Data.ParameterDirection.Input;
            spQuoteID.Value = quoteID;
            cmd.Parameters.Add(spQuoteID);

            SqlParameter spAnnuitantID = new SqlParameter("@AnnuitantID", System.Data.SqlDbType.Int);
            spAnnuitantID.Direction = System.Data.ParameterDirection.Input;
            spAnnuitantID.Value = annuitantID;
            cmd.Parameters.Add(spAnnuitantID);

            SqlParameter spDOB = new SqlParameter("@DOB", System.Data.SqlDbType.Date);
            spDOB.Direction = System.Data.ParameterDirection.Input;
            spDOB.Value = dob;
            cmd.Parameters.Add(spDOB);

            SqlParameter spFirstName = new SqlParameter("@FirstName", System.Data.SqlDbType.VarChar);
            spFirstName.Direction = System.Data.ParameterDirection.Input;
            spFirstName.Size = 50;
            spFirstName.Value = firstName;
            cmd.Parameters.Add(spFirstName);

            SqlParameter spLastName = new SqlParameter("@LastName", System.Data.SqlDbType.VarChar);
            spLastName.Direction = System.Data.ParameterDirection.Input;
            spLastName.Size = 50;
            spLastName.Value = lastName;
            cmd.Parameters.Add(spLastName);

            SqlParameter spRatedAge = new SqlParameter("@RatedAge", System.Data.SqlDbType.Int);
            spRatedAge.Direction = System.Data.ParameterDirection.Input;
            spRatedAge.Value = ratedAge;
            cmd.Parameters.Add(spRatedAge);

            SqlParameter spGender = new SqlParameter("@Gender", System.Data.SqlDbType.Char);
            spGender.Direction = System.Data.ParameterDirection.Input;
            spGender.Size = 1;
            spGender.Value = gender;
            cmd.Parameters.Add(spGender);

            try
            {
                conn.Open();
                cmd.ExecuteNonQuery();

                if ((int)cmd.Parameters["@RETURN_VALUE"].Value == 1)
                {

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
