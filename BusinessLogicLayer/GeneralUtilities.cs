using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace BusinessLogicLayer
{
    public class GeneralUtilities
    {
        public static string FormatPhone(string n)
        {
            string returnNumber = n;
            //Handle US Phones (10 digits) or else don't format
            if (!String.IsNullOrEmpty(n) && n.Length == 10)
            {
                string areaCode = n.Substring(0, 3);
                string usPrefix = n.Substring(3, 3);
                string usNum = n.Substring(6, 4);
                returnNumber = String.Format("({0}) {1}-{2}", areaCode, usPrefix, usNum);
            }
            return returnNumber;
        }

    }
}
