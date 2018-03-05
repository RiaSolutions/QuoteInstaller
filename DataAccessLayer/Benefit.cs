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
    public class Benefit
    {
        private static String GetConnectionString()
        {
            return ConfigurationManager.ConnectionStrings["DefaultConnection"].ToString();
        }
        public void FillBenefitComboBox(ref SqlDataAdapter da)
        {
            String strConnString = GetConnectionString();
            SqlConnection conn = new SqlConnection(strConnString);
//            da = new SqlDataAdapter(@"SELECT BenefitID, BenefitDescr from qte.benefit ORDER BY DropDownOrder", conn);
            da = new SqlDataAdapter(@"SELECT BenefitID, BenefitDescr from qte.benefit WHERE BenefitDescr NOT IN ('Joint Life', 'Endowment', 'Upfront Cash') ORDER BY DropDownOrder", conn);
        }
    }
}
