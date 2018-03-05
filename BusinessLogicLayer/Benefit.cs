using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.Data.SqlClient;
using System.Data;
using System.Configuration;

namespace BusinessLogicLayer
{
    public class Benefit
    {
        public void FillBenefitComboBox(ref SqlDataAdapter da)
        {
            DataAccessLayer.Benefit b = new DataAccessLayer.Benefit();
            b.FillBenefitComboBox(ref da);
        }
    }
}
