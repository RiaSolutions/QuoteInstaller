using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.ComponentModel;

//using System.Configuration;
using System.Data.SqlClient;
//using System.Data;

namespace BusinessLogicLayer
{
    public class Annuitant : BaseINPC
    {
        private string _firstName;
        private string _lastName;
        private DateTime _dob;
        private char _gender;
        private int _ratedAge;

        public string FirstName
        {
            get { return _firstName; }
            set { _firstName = value;
            RaisePropertyChanged("FirstName");
            }
        }

        public override bool Equals(object obj)
        {
            return obj is Annuitant && ((Annuitant)obj).FirstName.Equals(FirstName);
        }

        public override int GetHashCode()
        {
            return FirstName.GetHashCode();
        }

        public void FillAnnuitantComboBox(ref SqlDataAdapter da, int quoteID)
        {
            DataAccessLayer.Annuitant a = new DataAccessLayer.Annuitant();
            a.FillAnnuitantComboBox(ref da, quoteID);
        }

        public void AddAnnuitant(int quoteID, int annuitantID, DateTime dob,
            string firstName, string lastName, int ratedAge, char gender)
        {
            DataAccessLayer.Annuitant a = new DataAccessLayer.Annuitant();
            a.AddAnnuitant(quoteID, annuitantID, dob, firstName, lastName, ratedAge, gender);
        }


    }
}
