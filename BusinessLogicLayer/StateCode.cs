using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Data.SqlClient;
using System.Data;

namespace BusinessLogicLayer
{
    public class StateCode
    {
        public void FillStateComboBox(ref SqlDataAdapter da)
        {
            DataAccessLayer.StateCode sc = new DataAccessLayer.StateCode();
            sc.FillStateComboBox(ref da);
        }
    }
}
