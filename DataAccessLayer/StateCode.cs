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
    public class StateCode
    {
        private static String GetConnectionString()
        {
            return ConfigurationManager.ConnectionStrings["DefaultConnection"].ToString();
        }
        public void FillStateComboBox(ref SqlDataAdapter da)
        {
            String strConnString = GetConnectionString();
            SqlConnection conn = new SqlConnection(strConnString);
            da = new SqlDataAdapter(@"SELECT StateCode, StateName FROM qte.StateCode ORDER BY StateCode", conn);
        }
    }
}
