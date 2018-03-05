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
    public class Broker
    {
        private static String GetConnectionString()
        {
            return ConfigurationManager.ConnectionStrings["DefaultConnection"].ToString();
        }

        public void FillBrokerComboBox(ref SqlDataAdapter da)
        {
            String strConnString = GetConnectionString();
            SqlConnection conn = new SqlConnection(strConnString);
            da = new SqlDataAdapter(@"SELECT StlmtBrokerID, dbo.DisplayName(NULL, FirstName, MiddleInitial, LastName, NULL, EntityName, 31) AS BrokerName from qte.StlmtBroker ORDER BY dbo.DisplayName(NULL, FirstName, MiddleInitial, LastName, NULL, EntityName, 31)", conn);
        }

        public void FillBrokerDataGrid(ref DataTable dt)
        {
            string ConString = GetConnectionString();
            string CmdString = string.Empty;
            using (SqlConnection con = new SqlConnection(ConString))
            {
                SqlCommand cmd = new SqlCommand("qte.uspGetBrokerGrid", con);
                cmd.CommandType = CommandType.StoredProcedure;
                SqlDataAdapter sda = new SqlDataAdapter();
                sda.SelectCommand = cmd;
                sda.Fill(dt);
            }
        }

        public void AddBroker(int stlmtBrokerID, string firstName, char middleInitial, string lastName, string entityName, string addrLine1, string addrLine2,
            string addrLine3, string city, string stateCode, string zipCode5, string phoneNum)
        {

            String strConnString = GetConnectionString();
            SqlConnection conn = new SqlConnection(strConnString);
            SqlCommand cmd = new SqlCommand("qte.uspUpsertBroker", conn);
            cmd.CommandType = System.Data.CommandType.StoredProcedure;

            SqlParameter returnvalue = new SqlParameter("@RETURN_VALUE", System.Data.SqlDbType.Int);
            returnvalue.Direction = System.Data.ParameterDirection.ReturnValue;
            cmd.Parameters.Add(returnvalue);

            SqlParameter spStlmtBrokerID = new SqlParameter("@StlmtBrokerID", System.Data.SqlDbType.Int);
            spStlmtBrokerID.Direction = System.Data.ParameterDirection.Input;
            spStlmtBrokerID.Value = stlmtBrokerID;
            cmd.Parameters.Add(spStlmtBrokerID);

            SqlParameter spFirstName = new SqlParameter("@FirstName", System.Data.SqlDbType.VarChar);
            spFirstName.Direction = System.Data.ParameterDirection.Input;
            spFirstName.Size = 50;
            spFirstName.Value = firstName;
            cmd.Parameters.Add(spFirstName);

            SqlParameter spMiddleInitial = new SqlParameter("@MiddleInitial", System.Data.SqlDbType.Char);
            spMiddleInitial.Direction = System.Data.ParameterDirection.Input;
            spMiddleInitial.Size = 1;
            spMiddleInitial.Value = middleInitial;
            cmd.Parameters.Add(spMiddleInitial);

            SqlParameter spLastName = new SqlParameter("@LastName", System.Data.SqlDbType.VarChar);
            spLastName.Direction = System.Data.ParameterDirection.Input;
            spLastName.Size = 50;
            spLastName.Value = lastName;
            cmd.Parameters.Add(spLastName);

            SqlParameter spEntityName = new SqlParameter("@EntityName", System.Data.SqlDbType.VarChar);
            spEntityName.Direction = System.Data.ParameterDirection.Input;
            spEntityName.Size = 100;
            spEntityName.Value = entityName;
            cmd.Parameters.Add(spEntityName);

            SqlParameter spAddrLine1 = new SqlParameter("@AddrLine1", System.Data.SqlDbType.VarChar);
            spAddrLine1.Direction = System.Data.ParameterDirection.Input;
            spAddrLine1.Size = 100;
            spAddrLine1.Value = addrLine1;
            cmd.Parameters.Add(spAddrLine1);

            SqlParameter spAddrLine2 = new SqlParameter("@AddrLine2", System.Data.SqlDbType.VarChar);
            spAddrLine2.Direction = System.Data.ParameterDirection.Input;
            spAddrLine2.Size = 100;
            spAddrLine2.Value = addrLine2;
            cmd.Parameters.Add(spAddrLine2);

            SqlParameter spAddrLine3 = new SqlParameter("@AddrLine3", System.Data.SqlDbType.VarChar);
            spAddrLine3.Direction = System.Data.ParameterDirection.Input;
            spAddrLine3.Size = 100;
            spAddrLine3.Value = addrLine3;
            cmd.Parameters.Add(spAddrLine3);

            SqlParameter spCity = new SqlParameter("@City", System.Data.SqlDbType.VarChar);
            spCity.Direction = System.Data.ParameterDirection.Input;
            spCity.Size = 100;
            spCity.Value = city;
            cmd.Parameters.Add(spCity);

            SqlParameter spStateCode = new SqlParameter("@StateCode", System.Data.SqlDbType.Char);
            spStateCode.Direction = System.Data.ParameterDirection.Input;
            spStateCode.Size = 2;
            spStateCode.Value = stateCode;
            cmd.Parameters.Add(spStateCode);

            SqlParameter spZipCode5 = new SqlParameter("@ZipCode5", System.Data.SqlDbType.Char);
            spZipCode5.Direction = System.Data.ParameterDirection.Input;
            spZipCode5.Size = 5;
            spZipCode5.Value = zipCode5;
            cmd.Parameters.Add(spZipCode5);

            SqlParameter spPhoneNum = new SqlParameter("@PhoneNum", System.Data.SqlDbType.Char);
            spPhoneNum.Direction = System.Data.ParameterDirection.Input;
            spPhoneNum.Size = 10;
            spPhoneNum.Value = phoneNum;
            cmd.Parameters.Add(spPhoneNum);

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
        public void GetBroker(int stlmtBrokerID, ref string firstName, ref char middleInitial, ref string lastName, ref string entityName, ref string addrLine1, ref string addrLine2,
            ref string addrLine3, ref string city, ref string stateCode, ref string zipCode5, ref string phoneNum)
        {

            String strConnString = GetConnectionString();
            SqlConnection conn = new SqlConnection(strConnString);
            SqlCommand cmd = new SqlCommand("qte.uspGetStlmtBroker", conn);
            cmd.CommandType = System.Data.CommandType.StoredProcedure;

            SqlParameter returnvalue = new SqlParameter("@RETURN_VALUE", System.Data.SqlDbType.Int);
            returnvalue.Direction = System.Data.ParameterDirection.ReturnValue;
            cmd.Parameters.Add(returnvalue);

            SqlParameter spStlmtBrokerID = new SqlParameter("@StlmtBrokerID", System.Data.SqlDbType.Int);
            spStlmtBrokerID.Direction = System.Data.ParameterDirection.Input;
            spStlmtBrokerID.Value = stlmtBrokerID;
            cmd.Parameters.Add(spStlmtBrokerID);

            SqlParameter spFirstName = new SqlParameter("@FirstName", System.Data.SqlDbType.VarChar);
            spFirstName.Direction = System.Data.ParameterDirection.Output;
            spFirstName.Size = 50;
            spFirstName.Value = firstName;
            cmd.Parameters.Add(spFirstName);

            SqlParameter spMiddleInitial = new SqlParameter("@MiddleInitial", System.Data.SqlDbType.Char);
            spMiddleInitial.Direction = System.Data.ParameterDirection.Output;
            spMiddleInitial.Size = 1;
            spMiddleInitial.Value = middleInitial;
            cmd.Parameters.Add(spMiddleInitial);

            SqlParameter spLastName = new SqlParameter("@LastName", System.Data.SqlDbType.VarChar);
            spLastName.Direction = System.Data.ParameterDirection.Output;
            spLastName.Size = 50;
            spLastName.Value = lastName;
            cmd.Parameters.Add(spLastName);

            SqlParameter spEntityName = new SqlParameter("@EntityName", System.Data.SqlDbType.VarChar);
            spEntityName.Direction = System.Data.ParameterDirection.Output;
            spEntityName.Size = 100;
            spEntityName.Value = entityName;
            cmd.Parameters.Add(spEntityName);

            SqlParameter spAddrLine1 = new SqlParameter("@AddrLine1", System.Data.SqlDbType.VarChar);
            spAddrLine1.Direction = System.Data.ParameterDirection.Output;
            spAddrLine1.Size = 100;
            spAddrLine1.Value = addrLine1;
            cmd.Parameters.Add(spAddrLine1);

            SqlParameter spAddrLine2 = new SqlParameter("@AddrLine2", System.Data.SqlDbType.VarChar);
            spAddrLine2.Direction = System.Data.ParameterDirection.Output;
            spAddrLine2.Size = 100;
            spAddrLine2.Value = addrLine2;
            cmd.Parameters.Add(spAddrLine2);

            SqlParameter spAddrLine3 = new SqlParameter("@AddrLine3", System.Data.SqlDbType.VarChar);
            spAddrLine3.Direction = System.Data.ParameterDirection.Output;
            spAddrLine3.Size = 100;
            spAddrLine3.Value = addrLine3;
            cmd.Parameters.Add(spAddrLine3);

            SqlParameter spCity = new SqlParameter("@City", System.Data.SqlDbType.VarChar);
            spCity.Direction = System.Data.ParameterDirection.Output;
            spCity.Size = 100;
            spCity.Value = city;
            cmd.Parameters.Add(spCity);

            SqlParameter spStateCode = new SqlParameter("@StateCode", System.Data.SqlDbType.Char);
            spStateCode.Direction = System.Data.ParameterDirection.Output;
            spStateCode.Size = 2;
            spStateCode.Value = stateCode;
            cmd.Parameters.Add(spStateCode);

            SqlParameter spZipCode5 = new SqlParameter("@ZipCode5", System.Data.SqlDbType.Char);
            spZipCode5.Direction = System.Data.ParameterDirection.Output;
            spZipCode5.Size = 5;
            spZipCode5.Value = zipCode5;
            cmd.Parameters.Add(spZipCode5);

            SqlParameter spPhoneNum = new SqlParameter("@PhoneNum", System.Data.SqlDbType.Char);
            spPhoneNum.Direction = System.Data.ParameterDirection.Output;
            spPhoneNum.Size = 10;
            spPhoneNum.Value = phoneNum;
            cmd.Parameters.Add(spPhoneNum);

            try
            {
                conn.Open();
                cmd.ExecuteNonQuery();

                if ((int)cmd.Parameters["@RETURN_VALUE"].Value == 0)
                {
                    firstName = cmd.Parameters["@FirstName"].Value.ToString() ?? "";
                    middleInitial = Char.IsLetterOrDigit(Convert.ToChar(cmd.Parameters["@MiddleInitial"].Value)) ? ' ' : Convert.ToChar(cmd.Parameters["@MiddleInitial"].Value);
                    lastName = cmd.Parameters["@LastName"].Value.ToString() ?? "";
                    entityName = cmd.Parameters["@EntityName"].Value.ToString() ?? "";
                    addrLine1 = cmd.Parameters["@AddrLine1"].Value.ToString() ?? "";
                    addrLine2 = cmd.Parameters["@AddrLine2"].Value.ToString() ?? "";
                    addrLine3 = cmd.Parameters["@AddrLine3"].Value.ToString() ?? "";
                    city = cmd.Parameters["@City"].Value.ToString() ?? "";
                    stateCode = cmd.Parameters["@StateCode"].Value.ToString() ?? "";
                    zipCode5 = cmd.Parameters["@ZipCode5"].Value.ToString() ?? "";
                    phoneNum = cmd.Parameters["@PhoneNum"].Value.ToString() ?? "";
                }
                else
                {
                    firstName = "";
                    middleInitial = ' ';
                    lastName = "";
                    entityName = "";
                    addrLine1 = "";
                    addrLine2 = "";
                    addrLine3 = "";
                    city = "";
                    stateCode = "";
                    zipCode5 = "";
                    phoneNum = "";
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
        public string DeleteBroker(int stlmtBrokerID)
        {
            string returnMsg = "Successfully deleted the broker";
            String strConnString = GetConnectionString();
            SqlConnection conn = new SqlConnection(strConnString);
            SqlCommand cmd = new SqlCommand("qte.uspDeleteBroker", conn);
            cmd.CommandType = System.Data.CommandType.StoredProcedure;

            SqlParameter returnvalue = new SqlParameter("@RETURN_VALUE", System.Data.SqlDbType.Int);
            returnvalue.Direction = System.Data.ParameterDirection.ReturnValue;
            cmd.Parameters.Add(returnvalue);

            SqlParameter spStlmtBrokerID = new SqlParameter("@StlmtBrokerID", System.Data.SqlDbType.Int);
            spStlmtBrokerID.Direction = System.Data.ParameterDirection.Input;
            spStlmtBrokerID.Value = stlmtBrokerID;
            cmd.Parameters.Add(spStlmtBrokerID);

            try
            {
                conn.Open();
                cmd.ExecuteNonQuery();

                if ((int)cmd.Parameters["@RETURN_VALUE"].Value == 1)
                {
                    returnMsg = "This broker has associated quotes.";
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
            return returnMsg;

        }

    }
}
