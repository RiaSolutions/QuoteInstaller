using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.Configuration;
using System.Data.SqlClient;
using System.Data;

namespace BusinessLogicLayer
{
    public class Broker
    {
        private int _brokerID;
        private string _firstName;
        private Char _middleInitial;
        private string _lastName;
        private string _entityName;
        private string _addrLine1;
        private string _addrLine2;
        private string _addrLine3;
        private string _city;
        private string _stateCode;
        private string _zipCode5;
        private string _phoneNum;

        public int BrokerID
        {
            get { return _brokerID; }
            set { _brokerID = value; }
        }
        public string FirstName
        {
            get { return _firstName; }
            set { _firstName = value; }
        }
        public Char MiddleInitial
        {
            get { return _middleInitial; }
            set { _middleInitial = value; }
        }
        public string LastName
        {
            get { return _lastName; }
            set { _lastName = value; }
        }
        public string EntityName
        {
            get { return _entityName; }
            set { _entityName = value; }
        }
        public string AddrLine1
        {
            get { return _addrLine1; }
            set { _addrLine1 = value; }
        }
        public string AddrLine2
        {
            get { return _addrLine2; }
            set { _addrLine2 = value; }
        }
        public string AddrLine3
        {
            get { return _addrLine3; }
            set { _addrLine3 = value; }
        }
        public string City
        {
            get { return _city; }
            set { _city = value; }
        }
        public string StateCode
        {
            get { return _stateCode; }
            set { _stateCode = value; }
        }
        public string ZipCode5
        {
            get { return _zipCode5; }
            set { _zipCode5 = value; }
        }
        public string PhoneNum
        {
            get { return _phoneNum; }
            set { _phoneNum = value; }
        }

        public Broker()
        {
            BrokerID = 0;
            FirstName = "";
            MiddleInitial = ' ';
            LastName = "";
            EntityName = "";
            AddrLine1 = "";
            AddrLine2 = "";
            AddrLine3 = "";
            City = "";
            StateCode = "NC";
            ZipCode5 = "";
            PhoneNum = "";
        }

        public void FillBrokerComboBox(ref SqlDataAdapter da)
        {
            DataAccessLayer.Broker brk = new DataAccessLayer.Broker();
            brk.FillBrokerComboBox(ref da);
        }
        public void AddBroker(int stlmtBrokerID, string firstName, char middleInitial, string lastName, string entityName, string addrLine1, string addrLine2,
            string addrLine3, string city, string stateCode, string zipCode5, string phoneNum)
        {
            DataAccessLayer.Broker b = new DataAccessLayer.Broker();
            b.AddBroker(stlmtBrokerID, firstName, middleInitial, lastName, entityName, addrLine1, addrLine2, addrLine3, city, stateCode, zipCode5, phoneNum);
        }
        public void FillBrokerDataGrid(ref DataTable dt)
        {
            DataAccessLayer.Broker brk = new DataAccessLayer.Broker();
            brk.FillBrokerDataGrid(ref dt);
        }
        public void GetBroker(int stlmtBrokerID)
        {
            DataAccessLayer.Broker brk = new DataAccessLayer.Broker();

            string tmpFirstName = "";
            char tmpMiddleInitial = ' ';
            string tmpLastName = "";
            string tmpEntityName = "";
            string tmpAddrLine1 = "";
            string tmpAddrLine2 = "";
            string tmpAddrLine3 = "";
            string tmpCity = "";
            string tmpStateCode = "";
            string tmpZipCode5 = "";
            string tmpPhoneNum = "";

            brk.GetBroker(stlmtBrokerID, ref tmpFirstName, ref tmpMiddleInitial, ref tmpLastName, ref tmpEntityName, ref tmpAddrLine1, ref tmpAddrLine2,
                ref tmpAddrLine3, ref tmpCity, ref tmpStateCode, ref tmpZipCode5, ref tmpPhoneNum);

            BrokerID = stlmtBrokerID;
            FirstName = tmpFirstName;
            MiddleInitial = tmpMiddleInitial;
            LastName = tmpLastName;
            EntityName = tmpEntityName;
            AddrLine1 = tmpAddrLine1;
            AddrLine2 = tmpAddrLine2;
            AddrLine3 = tmpAddrLine3;
            City = tmpCity;
            ZipCode5 = tmpZipCode5;
            PhoneNum = tmpPhoneNum;
        }
        public string DeleteBroker(int stlmtBrokerID)
        {
            DataAccessLayer.Broker b = new DataAccessLayer.Broker();
            return b.DeleteBroker(stlmtBrokerID);
        }
    }
}
