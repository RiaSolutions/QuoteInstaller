using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using System.Data.SqlClient;
using System.Data;
using BusinessLogicLayer;

namespace StlmQuoteWPF
{
    /// <summary>
    /// Interaction logic for BrokerWindow.xaml
    /// </summary>
    public partial class BrokerWindow : Window
    {
        public BrokerWindow()
        {
            InitializeComponent();

            try
            {
                BindStateComboBox(cmbState);

                BusinessLogicLayer.Broker brk = new Broker();

                DataTable dt = new DataTable("Brokers");
                brk.FillBrokerDataGrid(ref dt);
                dgBrokers.ItemsSource = dt.DefaultView;

            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message);
            }

        }
        public void BindStateComboBox(ComboBox comboBoxName)
        {

            SqlDataAdapter da = new SqlDataAdapter();
            BusinessLogicLayer.StateCode sc = new StateCode();
            sc.FillStateComboBox(ref da);

            DataSet ds = new DataSet();
            da.Fill(ds, "tblStateCodes");
            comboBoxName.ItemsSource = ds.Tables[0].DefaultView;
            comboBoxName.DisplayMemberPath = ds.Tables[0].Columns["StateCode"].ToString();
            comboBoxName.SelectedValuePath = ds.Tables[0].Columns["StateCode"].ToString();
            comboBoxName.SelectedIndex = 0;

        }
        private void MenuItem_Click(object sender, RoutedEventArgs e)
        {
            Application.Current.MainWindow.Show();
            Application.Current.MainWindow.Left = this.Left;
            Application.Current.MainWindow.Top = this.Top;

            this.Close();
        }
        private void MenuItem_Click_2(object sender, RoutedEventArgs e)
        {
            System.Windows.Application.Current.Shutdown();
        }

        private void btnAddBroker_Click(object sender, RoutedEventArgs e)
        {
            BusinessLogicLayer.Broker brk = new Broker();

            string firstName = "";
            if (!string.IsNullOrEmpty(txtFirstName.Text))
                firstName = txtFirstName.Text;

            char middleInitial = ' ';
            if (!string.IsNullOrEmpty(txtMiddleInitial.Text))
                middleInitial = Convert.ToChar(txtMiddleInitial.Text.Substring(0, 1));

            string lastName = "";
            if (!string.IsNullOrEmpty(txtLastName.Text))
                lastName = txtLastName.Text;

            string brokerage = "";
            if (!string.IsNullOrEmpty(txtBrokerage.Text))
                brokerage = txtBrokerage.Text;

            string address1 = "";
            if (!string.IsNullOrEmpty(txtAddress1.Text))
                address1 = txtAddress1.Text;

            string address2 = "";
            if (!string.IsNullOrEmpty(txtAddress2.Text))
                address2 = txtAddress2.Text;

            string address3 = "";
            if (!string.IsNullOrEmpty(txtAddress3.Text))
                address3 = txtAddress3.Text;

            string city = "";
            if (!string.IsNullOrEmpty(txtCity.Text))
                city = txtCity.Text;

            string zip = "";
            if (!string.IsNullOrEmpty(txtCity.Text))
                zip = txtCity.Text;

            string phone = "";
            if (!string.IsNullOrEmpty(txtPhone.Text))
                phone = txtPhone.Text;

            brk.AddBroker(0, firstName, middleInitial, lastName, brokerage, address1, address2, address3
                , city, cmbState.SelectedValue.ToString(), zip, phone);

            DataTable dt = new DataTable("Brokers");
            brk.FillBrokerDataGrid(ref dt);
            dgBrokers.ItemsSource = dt.DefaultView;
    
            txtFirstName.Text = "";
            txtMiddleInitial.Text = "";
            txtLastName.Text = "";
            txtBrokerage.Text = "";
            txtAddress1.Text = "";
            txtAddress2.Text = "";
            txtAddress3.Text = "";
            txtCity.Text = "";
            cmbState.SelectedIndex = 0;
            txtZip.Text = "";
            txtPhone.Text = "";

        }

        private void btnSaveBroker_Click(object sender, RoutedEventArgs e)
        {
            BusinessLogicLayer.Broker brk = new Broker();

            brk.AddBroker(Convert.ToInt16(App.Current.Properties["StlmntBrokerID"])
                , txtFirstName.Text, Convert.ToChar(txtMiddleInitial.Text.Substring(0, 1)), txtLastName.Text, txtBrokerage.Text, txtAddress1.Text
                , txtAddress2.Text, txtAddress3.Text, txtCity.Text, cmbState.SelectedValue.ToString(), txtZip.Text, txtPhone.Text);

            DataTable dt = new DataTable("Brokers");
            brk.FillBrokerDataGrid(ref dt);
            dgBrokers.ItemsSource = dt.DefaultView;

            ClearBrokerInputFields();
        }
        private void ClearBrokerInputFields()
        {
            txtFirstName.Text = "";
            txtMiddleInitial.Text = "";
            txtLastName.Text = "";
            txtBrokerage.Text = "";
            txtAddress1.Text = "";
            txtAddress2.Text = "";
            txtAddress3.Text = "";
            txtCity.Text = "";
            cmbState.SelectedIndex = 0;
            txtZip.Text = "";
            txtPhone.Text = "";
        }

        private void btnCancelEdit_Click(object sender, RoutedEventArgs e)
        {
            btnAddBroker.IsEnabled = true;
            btnSaveBroker.IsEnabled = false;
            btnCancelEdit.IsEnabled = false;

            ClearBrokerInputFields();
        }

        private void btnBrokerEdit_Click(object sender, RoutedEventArgs e)
        {
            DataRowView row = (DataRowView)((Button)e.Source).DataContext;

            //MessageBox.Show(row.Row.ItemArray[1].ToString());
            btnAddBroker.IsEnabled = false;
            btnSaveBroker.IsEnabled = true;
            btnCancelEdit.IsEnabled = true;

            BusinessLogicLayer.Broker brk = new Broker();
            brk.GetBroker(Convert.ToInt16(row.Row.ItemArray[0]));

            App.Current.Properties["StlmntBrokerID"] = Convert.ToInt16(row.Row.ItemArray[0]);

            txtFirstName.Text = brk.FirstName;
            txtMiddleInitial.Text = brk.MiddleInitial.ToString();
            txtLastName.Text = brk.LastName;
            txtBrokerage.Text = brk.EntityName;
            txtAddress1.Text = brk.AddrLine1;
            txtAddress2.Text = brk.AddrLine2;
            txtAddress3.Text = brk.AddrLine3;
            txtCity.Text = brk.City;
            cmbState.SelectedValue = brk.StateCode;
            txtZip.Text = brk.ZipCode5;
            txtPhone.Text = brk.PhoneNum;

        }

        private void btnBrokerDelete_Click(object sender, RoutedEventArgs e)
        {
            string returnMsg;
            DataRowView row = (DataRowView)((Button)e.Source).DataContext;

            BusinessLogicLayer.Broker brk = new Broker();
            returnMsg = brk.DeleteBroker(Convert.ToInt16(row.Row.ItemArray[0]));

            DataTable dt = new DataTable("Brokers");
            brk.FillBrokerDataGrid(ref dt);
            dgBrokers.ItemsSource = dt.DefaultView;

            MessageBox.Show(returnMsg);

        }

        private void Window_Closing(object sender, System.ComponentModel.CancelEventArgs e)
        {
            //System.Windows.Application.Current.Shutdown();
        }
    }
}
