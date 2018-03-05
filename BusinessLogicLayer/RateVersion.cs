using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Data.SqlClient;

namespace BusinessLogicLayer
{
    public class RateVersion
    {
        private int _rateVersionID;
        private string _rateDescr;

        public int RateVersionID
        {
            get { return _rateVersionID; }
            set { _rateVersionID = value; }
        }
        public string RateDescr
        {
            get { return _rateDescr; }
            set { _rateDescr = value; }
        }
        public RateVersion()
        {
            RateVersionID = 0;
            RateDescr = "n/a";
        }
        public void GetCurrentRate()
        {
            using (SqlConnection conn = new SqlConnection(@"Data Source=(LocalDB)\v11.0;AttachDbFilename=|DataDirectory|\IQSMaster.mdf;Integrated Security=True"))
            {
                SqlCommand cmd = new SqlCommand("qte.uspGetCurrentRateVersion", conn);

                cmd.CommandType = System.Data.CommandType.StoredProcedure;

                SqlParameter returnvalue = new SqlParameter("@RETURN_VALUE", System.Data.SqlDbType.Int);
                returnvalue.Direction = System.Data.ParameterDirection.ReturnValue;
                cmd.Parameters.Add(returnvalue);

                SqlParameter spRateVersionID = new SqlParameter("@RateVersionID", System.Data.SqlDbType.Int);
                spRateVersionID.Direction = System.Data.ParameterDirection.Output;
                cmd.Parameters.Add(spRateVersionID);

                SqlParameter spRateDescr = new SqlParameter("@RateDescr", System.Data.SqlDbType.VarChar);
                spRateDescr.Direction = System.Data.ParameterDirection.Output;
                spRateDescr.Size = 50;
                cmd.Parameters.Add(spRateDescr);


                try
                {
                    conn.Open();
                    cmd.ExecuteNonQuery();

                    if ((int)cmd.Parameters["@RETURN_VALUE"].Value == 0)
                    {
                        RateVersionID = (int)cmd.Parameters["@RateVersionID"].Value;
                        RateDescr = (string)cmd.Parameters["@RateDescr"].Value;

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
}
