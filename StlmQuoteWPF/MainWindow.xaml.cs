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
using System.Windows.Navigation;
using System.Windows.Shapes;

using BusinessLogicLayer;
using System.Data.SqlClient;
using System.Data;

using Telerik.Windows.Controls.MaskedInput;

namespace StlmQuoteWPF
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        private bool calcPremiumAmt = false;
        private bool calcBenefitAmt = false;

        public MainWindow()
        {
            InitializeComponent();
            DataContext = this;

            // Default
            //txtBenefitAmt.Text = "1000.00";
            txtBenefitAmt.Value = 1000.0m;

            //txtFirstPayment.Text = DateTime.Now.AddDays(60).ToString("MMddyyyy");
            txtFirstPayment.Text = DateTime.Now.AddMonths(2).ToString("MMddyyyy");
            txtYears.Text = "20";

            //============================================================================================================
            txtFirstName.Text = "John";
            txtLastName.Text = "Doe";
            txtDOB.Text = "08/11/1981";
            txtRatedAge.Text = "36";
            rbFemale.IsChecked = false;
            rbMale.IsChecked = true;


            App.Current.Properties["QuoteID"] = 1;
            //////////////////////txtBudgetAmt.Text = "500000";
            txtBudgetAmt.Value = 100000;

            //// Case #2
            //txtFirstName.Text = "John";
            //txtLastName.Text = "Cust #2";
            //txtDOB.Text = "01/09/1969";
            //txtRatedAge.Text = "49";
            //rbFemale.IsChecked = false;
            //rbMale.IsChecked = true;

            //txtBenefitAmt.Text = "42589.29";
            //txtFirstPayment.Text = "01152043";
            //txtYears.Text = "";

            //App.Current.Properties["QuoteID"] = 1;
            //txtBudgetAmt.Text = "500000";

            //============================================================================================================

            App.Current.Properties["StlmtBrokerID"] = 1;
            App.Current.Properties["ProductCnt"] = 0;

            txtQuoteDate.Text = DateTime.Now.ToString("MM/dd/yyyy");
            //txtPurchaseDate.Text = DateTime.Now.AddDays(30).ToString("MMddyyyy");
            txtPurchaseDate.Text = DateTime.Now.AddMonths(1).ToString("MMddyyyy");
            
            btnAddAnnuitant.IsEnabled = false;
            btnAddBenefitQuote.IsEnabled = false;
            
            cmbType.IsEnabled = false;
            cmbAnnuitant.IsEnabled = false;
            cmbMode.IsEnabled = false;
            txtBenefitAmt.IsEnabled = false;
            txtPremiumAmt.IsEnabled = false;
            txtFirstPayment.IsEnabled = false;
            txtSurvivorPct.IsEnabled = false;
            //cmbJointAnnuitant.IsEnabled = false;
            //txtJointSurvivorPct.IsEnabled = false;
            txtEnds.IsEnabled = false;
            txtYears.IsEnabled = false;
            txtMonths.IsEnabled = false;
            txtIncrPct.IsEnabled = false;

            try
            {
                RateVersion rv = new RateVersion();
                rv.GetCurrentRate();
                txtRateVersion.Text = rv.RateDescr;
                App.Current.Properties["RateVersionID"] = rv.RateVersionID;

                BindBrokerComboBox(cmbBroker);

                BindTypeComboBox(cmbType);

                App.Current.Properties["TotalPremiumAmt"] = "0";
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message);
            }

        }

        public void BindBrokerComboBox(ComboBox comboBoxName)
        {

            SqlDataAdapter da = new SqlDataAdapter();
            BusinessLogicLayer.Broker brk = new Broker();
            brk.FillBrokerComboBox(ref da);
            
            DataSet ds = new DataSet();
            da.Fill(ds, "tblBrokers");
            comboBoxName.ItemsSource = ds.Tables[0].DefaultView;
            comboBoxName.DisplayMemberPath = ds.Tables[0].Columns["BrokerName"].ToString();
            comboBoxName.SelectedValuePath = ds.Tables[0].Columns["StlmtBrokerID"].ToString();
            comboBoxName.SelectedIndex = 0;

        }

        public void BindTypeComboBox(ComboBox comboBoxName)
        {

            SqlDataAdapter da = new SqlDataAdapter();
            BusinessLogicLayer.Benefit bnf = new Benefit();
            bnf.FillBenefitComboBox(ref da);

            DataSet ds = new DataSet();
            da.Fill(ds, "tblBenefits");
            comboBoxName.ItemsSource = ds.Tables[0].DefaultView;
            comboBoxName.DisplayMemberPath = ds.Tables[0].Columns["BenefitDescr"].ToString();
            comboBoxName.SelectedValuePath = ds.Tables[0].Columns["BenefitID"].ToString();
            comboBoxName.SelectedIndex = 0;

        }

        private void cmbType_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            //ComboBox combobox = sender as ComboBox;
            //MessageBox.Show("cmbType_SelectionChanged " + combobox.Text);

            //string tmp = ((ComboBoxItem)cmbType.SelectedItem).Content.ToString();


            //MessageBox.Show(tmp);

        }

        private void AddBenefitQuote(int benefitQuoteID, Boolean persist, Boolean editExisting)
        {
            DateTime tmpDate;
            if(!DateTime.TryParse(txtFirstPayment.Text, out tmpDate))
            {
                MessageBox.Show("Please add a valid date for the First Payment.", "Incomplete fields", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            else
            {
                DateTime tmpEndDate;

                if (txtEnds.Text.ToString().Length == 0)
                    tmpEndDate = Convert.ToDateTime("1/1/0001");
                else
                    tmpEndDate = Convert.ToDateTime(txtEnds.Text);

                int tmpYears;
                int tmpMonths;
                decimal tmpIncrPct;
                char tmpMode;

                switch (cmbType.Text)
                {
                    case "Life":
                        if (txtYears.Text.Length == 0)
                            tmpYears = 0;
                        else
                            tmpYears = Convert.ToInt16(txtYears.Text);
                        if (txtMonths.Text.Length == 0)
                            tmpMonths = 0;
                        else
                            tmpMonths = Convert.ToInt16(txtMonths.Text);
                        if (txtIncrPct.Text.Length == 0)
                            tmpIncrPct = 0.0m;
                        else
                            tmpIncrPct = Convert.ToDecimal(txtIncrPct.Text);
                        tmpMode = Convert.ToChar(((ComboBoxItem)cmbMode.SelectedValue).Content.ToString().Substring(0, 1));
                        break;
                    case "Period Certain":
                    case "Temporary Life":
                        if (txtYears.Text.Length == 0)
                            tmpYears = 0;
                        else
                            tmpYears = Convert.ToInt16(txtYears.Text);
                        if (txtMonths.Text.Length == 0)
                            tmpMonths = 0;
                        else
                            tmpMonths = Convert.ToInt16(txtMonths.Text);
                        if (txtIncrPct.Text.Length == 0)
                            tmpIncrPct = 0.0m;
                        else
                            tmpIncrPct = Convert.ToDecimal(txtIncrPct.Text);
                        tmpMode = Convert.ToChar(((ComboBoxItem)cmbMode.SelectedValue).Content.ToString().Substring(0, 1));
                        break;
                    case "Lump Sum":
                        tmpYears = 0;
                        tmpMonths = 0;
                        tmpIncrPct = 0.0m;
                        tmpMode = 'x';
                        break;
                    default:
                        tmpYears = 0;
                        tmpMonths = 0;
                        tmpIncrPct = 0.0m;
                        tmpMode = 'x';
                        break;
                }

                //Tmp fix
                //tmpIncrPct = 0.0m;

                BusinessLogicLayer.BenefitQuote bq = new BenefitQuote();

                bq.SaveBenefitQuote(benefitQuoteID, Convert.ToInt16(App.Current.Properties["QuoteID"]), Convert.ToInt16(cmbType.SelectedValue)
                    , Convert.ToInt16(cmbAnnuitant.SelectedValue), Convert.ToInt16(cmbAnnuitant.SelectedValue), tmpMode
//                    , Convert.ToDecimal((txtBenefitAmt.Text == "" ? "0" : txtBenefitAmt.Text))
                    , Convert.ToDecimal(txtBenefitAmt.Value)
//                    , Convert.ToDecimal((txtPremiumAmt.Text == "" ? "0" : txtPremiumAmt.Text))
                    , Convert.ToDecimal(txtPremiumAmt.Value)
                    , Convert.ToDateTime(txtFirstPayment.Text), tmpYears, tmpMonths, tmpIncrPct, tmpEndDate, persist);

                DataTable dt = new DataTable("BenefitQuote");
                bq.FillBenefitQuoteDataGrid(ref dt, Convert.ToInt16(App.Current.Properties["QuoteID"]));

                if (persist)
                {
                    decimal _totalPremiumAmt = Convert.ToDecimal(App.Current.Properties["TotalPremiumAmt"].ToString());
                    if (!editExisting)
                    {
                        _totalPremiumAmt = bq.PremiumAmt + _totalPremiumAmt;
                    }
                    else
                    {
                        _totalPremiumAmt = bq.PremiumAmt + _totalPremiumAmt - Convert.ToDecimal(App.Current.Properties["OrigPremiumAmt"].ToString());
                    }
                    App.Current.Properties["TotalPremiumAmt"] = _totalPremiumAmt.ToString();
                    lblTotalPremiumAmt.Content = _totalPremiumAmt.ToString("C");
                    lblTotalRemainingAmt.Content = (Convert.ToDecimal(txtBudgetAmt.Value) - _totalPremiumAmt - 750.0m).ToString("C");
                }
                App.Current.Properties["PaymentValueAmt"] = bq.PaymentValueAmt.ToString();
                App.Current.Properties["BenefitAmt"] = bq.BenefitAmt.ToString();
                App.Current.Properties["PremiumAmt"] = bq.PremiumAmt.ToString();

                ClearBenefitQuoteInputFields();
                dgBenefits.ItemsSource = dt.DefaultView;

            }

        }

        private void btnAddBenefitQuote_Click(object sender, RoutedEventArgs e)
        {
            Mouse.OverrideCursor = System.Windows.Input.Cursors.Wait;

            AddBenefitQuote(0, true, false);
            btnReport.IsEnabled = true;

            Mouse.OverrideCursor = System.Windows.Input.Cursors.Arrow;
        }

        private void cmbType_DropDownClosed(object sender, EventArgs e)
        {
            ComboBox combobox = sender as ComboBox;
            cmbMode.Visibility = System.Windows.Visibility.Visible;
            cmbModeNA.Visibility = System.Windows.Visibility.Hidden;

            switch (combobox.Text)
            {
                case "Life":
                    cmbMode.IsEnabled = true;
                    txtFirstPayment.IsEnabled = true;
                    txtYears.IsEnabled = true;
                    txtMonths.IsEnabled = true;
                    txtIncrPct.IsEnabled = true;
                    txtEnds.IsEnabled = false;
                    txtEnds.Text = "";
                    break;
                case "Period Certain":
                    cmbMode.IsEnabled = true;
                    txtFirstPayment.IsEnabled = true;
                    txtYears.IsEnabled = true;
                    txtMonths.IsEnabled = true;
                    txtIncrPct.IsEnabled = true;
                    txtEnds.IsEnabled = false;
                    txtEnds.Text = "";
                    break;
                case "Lump Sum":
                    cmbMode.IsEnabled = false;

                    cmbMode.Visibility = System.Windows.Visibility.Hidden;
                    cmbModeNA.Visibility = System.Windows.Visibility.Visible;

                    txtFirstPayment.IsEnabled = true;
                    txtYears.IsEnabled = false;
                    txtYears.Text = "";
                    txtMonths.IsEnabled = false;
                    txtMonths.Text = "";
                    txtIncrPct.IsEnabled = false;
                    txtIncrPct.Text = "";
                    txtEnds.IsEnabled = false;
                    txtEnds.Text = "";
                    break;
                case "Endowment":
                    cmbMode.IsEnabled = false;
                    txtFirstPayment.IsEnabled = true;
                    txtYears.IsEnabled = false;
                    txtYears.Text = "";
                    txtMonths.IsEnabled = false;
                    txtMonths.Text = "";
                    txtIncrPct.IsEnabled = false;
                    txtIncrPct.Text = "";
                    txtEnds.IsEnabled = false;
                    txtEnds.Text = "";
                    break;
                case "Temporary Life":
                    cmbMode.IsEnabled = true;
                    txtFirstPayment.IsEnabled = true;
                    txtYears.IsEnabled = true;
                    txtMonths.IsEnabled = false;
                    txtMonths.Text = "";
                    txtIncrPct.IsEnabled = true;
                    txtEnds.IsEnabled = false;
                    txtEnds.Text = "";
                    break;
                case "Upfront Cash":
                    cmbMode.IsEnabled = false;
                    txtFirstPayment.IsEnabled = false;
                    txtYears.IsEnabled = false;
                    txtYears.Text = "";
                    txtMonths.IsEnabled = false;
                    txtMonths.Text = "";
                    txtIncrPct.IsEnabled = false;
                    txtIncrPct.Text = "";
                    txtEnds.IsEnabled = false;
                    txtEnds.Text = "";
                    break;
                case "Joint Life":
                    cmbMode.IsEnabled = true;
                    txtFirstPayment.IsEnabled = true;
                    txtYears.IsEnabled = false;
                    txtYears.Text = "";
                    txtMonths.IsEnabled = false;
                    txtMonths.Text = "";
                    txtIncrPct.IsEnabled = true;
                    txtEnds.IsEnabled = false;
                    txtEnds.Text = "";
                    break;
            }

        }

        private void btnAddAnnuitant_Click(object sender, RoutedEventArgs e)
        {
            btnAddAnnuitant.IsEnabled = false;
            Mouse.OverrideCursor = System.Windows.Input.Cursors.Wait;

            BusinessLogicLayer.Annuitant ann = new Annuitant();
            char tmpGender;

            if (rbMale.IsChecked == true)
                tmpGender = 'M';
            else
                tmpGender = 'F';

            if(String.IsNullOrEmpty(txtDOB.Text)
                || String.IsNullOrEmpty(txtFirstName.Text)
                || String.IsNullOrEmpty(txtLastName.Text)
                || String.IsNullOrEmpty(txtRatedAge.Text))
            {
                MessageBox.Show("Please complete Annuitant information before adding.","Incomplete fields",MessageBoxButton.OK,MessageBoxImage.Information);
            }
            else
            {
                ann.AddAnnuitant(Convert.ToInt16(App.Current.Properties["QuoteID"])
                    , 0
                    , Convert.ToDateTime(txtDOB.Text),
                    txtFirstName.Text, txtLastName.Text
                    , Convert.ToInt16(txtRatedAge.Text)
                    , tmpGender);

                App.Current.Properties["AnnuitantName"] = txtFirstName.Text + " " + txtLastName.Text;

                var today = DateTime.Today;
                var age = today.Year - Convert.ToDateTime(txtDOB.Text).Year;
                if (Convert.ToDateTime(txtDOB.Text) > today.AddYears(-age)) age--;
                if(age.ToString() != txtRatedAge.Text)
                {
                    App.Current.Properties["GenderAge"] = tmpGender + ", " + txtDOB.Text + ", "
                        + age.ToString() + ", " + txtRatedAge.Text;
                    //App.Current.Properties["GenderAge"] = (tmpGender == 'M' ? "Male" : "Female") + ", " + txtDOB.Text + ", "
                    //    + age.ToString() + ", " + txtRatedAge.Text;
                    App.Current.Properties["GenderAgeLabel"] = "Gender, DOB, Age, Rated Age:";
                }
                else
                {
                    App.Current.Properties["GenderAge"] = tmpGender + ", " + txtDOB.Text + ", "
                        + age.ToString();
                    App.Current.Properties["GenderAgeLabel"] = "Gender, DOB, Age:";
                }

                SqlDataAdapter da = new SqlDataAdapter();
                BusinessLogicLayer.Annuitant ant = new Annuitant();
                ant.FillAnnuitantComboBox(ref da, Convert.ToInt16(App.Current.Properties["QuoteID"]));

                DataSet ds = new DataSet();
                da.Fill(ds, "tblAnnuitants");
                cmbAnnuitant.ItemsSource = ds.Tables[0].DefaultView;
                cmbAnnuitant.DisplayMemberPath = ds.Tables[0].Columns["AnnuitantName"].ToString();
                cmbAnnuitant.SelectedValuePath = ds.Tables[0].Columns["AnnuitantID"].ToString();
                cmbAnnuitant.SelectedIndex = 0;

                txtFirstName.Text = "";
                txtLastName.Text = "";
                txtDOB.Text = "";
                txtRatedAge.Text = "";
                btnAddBenefitQuote.IsEnabled = true;

                cmbType.IsEnabled = true;
                cmbAnnuitant.IsEnabled = true;
                cmbMode.IsEnabled = true;
                txtBenefitAmt.IsEnabled = true;
                txtPremiumAmt.IsEnabled = true;
                txtFirstPayment.IsEnabled = true;
                txtSurvivorPct.IsEnabled = true;
                //cmbJointAnnuitant.IsEnabled = true;
                //txtJointSurvivorPct.IsEnabled = true;
                txtEnds.IsEnabled = false;
                txtYears.IsEnabled = true;
                txtMonths.IsEnabled = true;
                txtIncrPct.IsEnabled = true;

                if (Convert.ToInt16(App.Current.Properties["ProductCnt"]) < 1)
                {
                    AddBenefitQuote(0, false, false);
                    calcPremiumAmt = true;
                    calcBenefitAmt = true;
                }

            }
            btnAddAnnuitant.IsEnabled = true;
            Mouse.OverrideCursor = System.Windows.Input.Cursors.Arrow;
        }

        private void btnBenefitQuote_Click(object sender, RoutedEventArgs e)
        {
            Mouse.OverrideCursor = System.Windows.Input.Cursors.Wait;
            DataRowView row = (DataRowView)((Button)e.Source).DataContext;

            //MessageBox.Show(row.Row.ItemArray[1].ToString());
            btnAddBenefitQuote.IsEnabled = false;
            btnSaveBenefitQuote.IsEnabled = true;
            btnCancelEdit.IsEnabled = true;

            BusinessLogicLayer.BenefitQuote bq = new BenefitQuote();
            bq.GetBenefitQuote(Convert.ToInt16(row.Row.ItemArray[0]));
            App.Current.Properties["BenefitQuoteID"] = Convert.ToInt16(row.Row.ItemArray[0]);

            cmbType.SelectedValue = bq.BenefitID;
            if (cmbType.Text == "Lump Sum")
            {
                cmbMode.Visibility = System.Windows.Visibility.Hidden;
                cmbModeNA.Visibility = System.Windows.Visibility.Visible;
            }

            //txtBenefitAmt.Text = bq.BenefitAmt.ToString();
            txtBenefitAmt.Value = bq.BenefitAmt;


            //txtPremiumAmt.Text = bq.PremiumAmt.ToString();
            txtPremiumAmt.Value = bq.PremiumAmt;
            App.Current.Properties["OrigPremiumAmt"] = bq.PremiumAmt.ToString();

            txtFirstPayment.Text = bq.FirstPaymentDate.ToString("MMddyyyy");
            //txtFirstPayment.Text = (bq.FirstPaymentDate.ToShortDateString()).Replace("/", "");

            txtYears.Text = bq.CertainYears.ToString();
            txtMonths.Text = bq.CertainMonths.ToString();
            txtIncrPct.Text = bq.ImprovementPct.ToString();
            txtEnds.Text = bq.EndDate.ToShortDateString();

            Mouse.OverrideCursor = System.Windows.Input.Cursors.Arrow;

        }

        private void btnSaveBenefitQuote_Click(object sender, RoutedEventArgs e)
        {
            Mouse.OverrideCursor = System.Windows.Input.Cursors.Wait;

            AddBenefitQuote(Convert.ToInt16(App.Current.Properties["BenefitQuoteID"]), true, true);

            Mouse.OverrideCursor = System.Windows.Input.Cursors.Arrow;
        }

        private void btnSaveQuote_Click(object sender, RoutedEventArgs e)
        {
            MessageBoxResult result;
            if(txtBudgetAmt.Value == 0)
            {
                result = MessageBox.Show("Budget is missing.  Do you want to continue with the quote?", "Warning", MessageBoxButton.YesNo, MessageBoxImage.Warning);
            }
            else
            {
                result = MessageBoxResult.Yes;
            }
            if(result == MessageBoxResult.Yes)
            {
                int rateVersionID = Convert.ToInt16(App.Current.Properties["RateVersionID"]);
                BusinessLogicLayer.Quote qte = new Quote();


                App.Current.Properties["QuoteID"] = qte.SaveQuote(0, Convert.ToInt16(cmbBroker.SelectedValue)
                    , rateVersionID, Convert.ToDateTime(txtPurchaseDate.Text), Convert.ToDecimal(txtBudgetAmt.Value));
                App.Current.Properties["StlmtBrokerID"] = Convert.ToInt16(cmbBroker.SelectedValue);

                btnAddAnnuitant.IsEnabled = true;
                //btnAddBenefitQuote.IsEnabled = true;

                btnSaveQuote.IsEnabled = false;
                txtPurchaseDate.IsEnabled = false;
                cmbBroker.IsEnabled = false;
                txtBudgetAmt.IsEnabled = false;

                lblTotalRemainingAmt.Content = (Convert.ToDecimal(txtBudgetAmt.Value) - 750.0m).ToString("C");
            }

        }

        private void btnCancelEdit_Click(object sender, RoutedEventArgs e)
        {
            btnAddBenefitQuote.IsEnabled = true;
            btnSaveBenefitQuote.IsEnabled = false;
            btnCancelEdit.IsEnabled = false;
            ClearBenefitQuoteInputFields();
        }

        private void btnReport_Click(object sender, RoutedEventArgs e)
        {

            QuoteIllustration qi = new QuoteIllustration();
            //qi.CreateQuoteIllustrationReport(Convert.ToInt16(App.Current.Properties["StlmtBrokerID"].ToString())
            //    , App.Current.Properties["AnnuitantName"].ToString()
            //    , App.Current.Properties["GenderAgeLabel"].ToString()
            //    , App.Current.Properties["GenderAge"].ToString()
            //    , Convert.ToDateTime(txtQuoteDate.Text)
            //    , Convert.ToDateTime(txtPurchaseDate.Text)
            //    , txtRateVersion.Text
            //    , dgBenefits);

            qi.CreateSettlementReport(Convert.ToInt16(App.Current.Properties["StlmtBrokerID"].ToString())
                , App.Current.Properties["AnnuitantName"].ToString()
                , App.Current.Properties["GenderAgeLabel"].ToString()
                , App.Current.Properties["GenderAge"].ToString()
                , Convert.ToDateTime(txtQuoteDate.Text)
                , Convert.ToDateTime(txtPurchaseDate.Text)
                , txtRateVersion.Text
                , dgBenefits
                , Convert.ToInt16(App.Current.Properties["QuoteID"]));

            //try
            //{
            //    System.Diagnostics.Process process = new System.Diagnostics.Process();

            //    Uri pdf = new Uri(qi.IllustrationReportName, UriKind.RelativeOrAbsolute);
            //    process.StartInfo.FileName = pdf.LocalPath;
            //    process.Start();
            //    //process.WaitForExit();
            //}
            //catch (Exception error)
            //{
            //    MessageBox.Show("Could not open the report.", "Error", MessageBoxButton.OK, MessageBoxImage.Warning);
            //    MessageBox.Show(error.Message, "Error", MessageBoxButton.OK, MessageBoxImage.Warning);
            //}

            try
            {
                System.Diagnostics.Process process = new System.Diagnostics.Process();

                Uri pdf = new Uri(qi.SettlementReportName, UriKind.RelativeOrAbsolute);
                process.StartInfo.FileName = pdf.LocalPath;
                process.Start();
                //process.WaitForExit();
            }
            catch (Exception error)
            {
                MessageBox.Show("Could not open the report.", "Error", MessageBoxButton.OK, MessageBoxImage.Warning);
                MessageBox.Show(error.Message, "Error", MessageBoxButton.OK, MessageBoxImage.Warning);
            }
            //string fileName = thisFileName;
            ////finalDoc.Save(Server.MapPath(thisFileName));
            ////string fileName = Server.MapPath(thisFileName);

            //FileInfo fileInfo = new FileInfo(fileName);

            //string responseHeader = "attachment; filename=" + fileInfo.Name;

            //Response.ContentType = "Application/pdf";
            //Response.AppendHeader("Content-Disposition", responseHeader);
            //Response.TransmitFile(fileName);
            //Response.End();

        }

        private void ClearBenefitQuoteInputFields()
        {
            calcPremiumAmt = false;
            calcBenefitAmt = false;

            btnAddBenefitQuote.IsEnabled = true;
            btnSaveBenefitQuote.IsEnabled = false;
            btnCancelEdit.IsEnabled = false;

            cmbType.SelectedIndex = 0;
            // Life fields
            cmbMode.IsEnabled = true;
            cmbMode.Visibility = System.Windows.Visibility.Visible;
            cmbModeNA.Visibility = System.Windows.Visibility.Hidden;

            txtFirstPayment.IsEnabled = true;
            txtYears.IsEnabled = true;
            txtMonths.IsEnabled = true;
            txtIncrPct.IsEnabled = true;
            txtEnds.IsEnabled = false;
            txtEnds.Text = "";

            cmbAnnuitant.SelectedIndex = 0;
            cmbMode.SelectedIndex = 0;
            //txtBenefitAmt.Text = "";
            //txtPremiumAmt.Text = "";
            txtPremiumAmt.Value = 0.0m;
            //txtFirstPayment.Text = "";
            txtSurvivorPct.Text = "";
            txtJointSurvivorPct.Text = "";
            txtEnds.Text = "";
            //txtYears.Text = "";
            txtMonths.Text = "";
            txtIncrPct.Text = "";

            // Default
            //txtBenefitAmt.Text = "1000.00";
            txtBenefitAmt.Value = 1000.0m;


            //txtFirstPayment.Text = DateTime.Now.AddMonths(1).ToString("MMddyyyy");
            //Convert.ToDateTime(txtPurchaseDate.Text).AddDays(30).ToString("MMddyyyy");
            //txtFirstPayment.Text = DateTime.Now.AddMonths(1).ToString("MMddyyyy");

            txtYears.Text = "20";
            calcPremiumAmt = true;
            calcBenefitAmt = true;

        }
        
        private void txtDOB_LostFocus(object sender, RoutedEventArgs e)
        {
            if (txtDOB.Text.Length > 0)
            {
                try
                {
                    var today = DateTime.Today;
                    var age = today.Year - Convert.ToDateTime(txtDOB.Text).Year;
                    if (Convert.ToDateTime(txtDOB.Text) > today.AddYears(-age)) age--;

                    txtRatedAge.Text = age.ToString();
                }
                catch (Exception ex)
                {
                    MessageBox.Show(ex.Message);
                }
            }

        }

        private void UpdateEndDate()
        {
            if (txtFirstPayment.Text.Length > 0 &&
                txtYears.Text.Length > 0 &&
                txtMonths.Text.Length > 0)
            {
                DateTime tmpStartDate = Convert.ToDateTime(txtFirstPayment.Text);
                tmpStartDate = tmpStartDate.AddYears(Convert.ToInt16(txtYears.Text));
                tmpStartDate = tmpStartDate.AddMonths(Convert.ToInt16(txtMonths.Text));
                txtEnds.Text = tmpStartDate.ToShortDateString();
            }
            else
                txtEnds.Text = "";
        }

        private void txtFirstPayment_LostFocus(object sender, RoutedEventArgs e)
        {
            UpdateEndDate();
        }

        private void txtYears_LostFocus(object sender, RoutedEventArgs e)
        {
            UpdateEndDate();
        }

        private void txtMonths_LostFocus(object sender, RoutedEventArgs e)
        {
            UpdateEndDate();
        }

        private void MenuItem_Click_1(object sender, RoutedEventArgs e)
        {
            BrokerWindow brokerWindow = new BrokerWindow();
            brokerWindow.Left = this.Left;
            brokerWindow.Top = this.Top;
            brokerWindow.Show();

            // Hide the MainWindow until later
            this.Hide();
        }

        private void MenuItem_Click_2(object sender, RoutedEventArgs e)
        {
            System.Windows.Application.Current.Shutdown();
        }

        private void txtBenefitAmt_TextChanged(object sender, TextChangedEventArgs e)
        {
            //decimal tmpBenefitAmt;
            //if (string.IsNullOrEmpty(txtBenefitAmt.Text))
            //    tmpBenefitAmt = 0.0m;
            //else
            //    tmpBenefitAmt = Convert.ToDecimal(txtBenefitAmt.Text);

            if (calcPremiumAmt == true)
            {
                calcBenefitAmt = false;
                decimal tmpPaymentValueAmt = Convert.ToDecimal(App.Current.Properties["PaymentValueAmt"].ToString());

                //App.Current.Properties["BenefitAmt"] = txtBenefitAmt.Text;
                App.Current.Properties["BenefitAmt"] = txtBenefitAmt.Value.ToString();
                //txtPremiumAmt.Text = (Decimal.Round(Convert.ToDecimal(txtBenefitAmt.Value) * tmpPaymentValueAmt / 0.95m, 2)).ToString();
                txtPremiumAmt.Value = Decimal.Round(Convert.ToDecimal(txtBenefitAmt.Value) * tmpPaymentValueAmt / 0.95m, 2);
                //App.Current.Properties["PremiumAmt"] = txtPremiumAmt.Text;
                App.Current.Properties["PremiumAmt"] = txtPremiumAmt.Value.ToString();
            }

        }

        private void txtPremiumAmt_TextChanged(object sender, TextChangedEventArgs e)
        {
            //decimal tmpPremiumAmt;
            //if (string.IsNullOrEmpty(txtPremiumAmt.Text))
            //    tmpPremiumAmt = 0.0m;
            //else
            //    tmpPremiumAmt = Convert.ToDecimal(txtPremiumAmt.Text);

            if (calcBenefitAmt == true)
            {
                calcPremiumAmt = false;
                decimal tmpPaymentValueAmt = Convert.ToDecimal(App.Current.Properties["PaymentValueAmt"].ToString());

                //App.Current.Properties["PremiumAmt"] = txtPremiumAmt.Text;
                App.Current.Properties["PremiumAmt"] = txtPremiumAmt.Value.ToString();
                //txtBenefitAmt.Text = (Decimal.Round(tmpPremiumAmt * 0.95m / tmpPaymentValueAmt, 2)).ToString();
                txtBenefitAmt.Value = Decimal.Round(Convert.ToDecimal(txtPremiumAmt.Value) * 0.95m / tmpPaymentValueAmt, 2);
                //App.Current.Properties["BenefitAmt"] = txtBenefitAmt.Text;
                App.Current.Properties["BenefitAmt"] = txtBenefitAmt.Value.ToString();
            }

        }

        private void txtPremiumAmt_LostFocus(object sender, RoutedEventArgs e)
        {
            calcPremiumAmt = true;
        }

        private void txtBenefitAmt_LostFocus(object sender, RoutedEventArgs e)
        {
            calcBenefitAmt = true;
        }

        private void btnDeleteBenefit_Click(object sender, RoutedEventArgs e)
        {
            Mouse.OverrideCursor = System.Windows.Input.Cursors.Wait;
            DataRowView row = (DataRowView)((Button)e.Source).DataContext;

            //MessageBox.Show(row.Row.ItemArray[1].ToString());
            decimal totalPremiumAmt = Convert.ToDecimal(App.Current.Properties["TotalPremiumAmt"].ToString());
            decimal premiumAmt = Convert.ToDecimal(row.Row.ItemArray[10]);

            BusinessLogicLayer.BenefitQuote bq = new BenefitQuote();
            bq.DeleteBenefitQuote(Convert.ToInt16(row.Row.ItemArray[0]));


            DataTable dt = new DataTable("BenefitQuote");
            bq.FillBenefitQuoteDataGrid(ref dt, Convert.ToInt16(App.Current.Properties["QuoteID"]));

            totalPremiumAmt = totalPremiumAmt - premiumAmt;

            App.Current.Properties["TotalPremiumAmt"] = totalPremiumAmt.ToString();
            lblTotalPremiumAmt.Content = totalPremiumAmt.ToString("C");
            lblTotalRemainingAmt.Content = (Convert.ToDecimal(txtBudgetAmt.Value) - totalPremiumAmt - 750.0m).ToString("C");

            dgBenefits.ItemsSource = dt.DefaultView;

            Mouse.OverrideCursor = System.Windows.Input.Cursors.Arrow;

        }

        private void txtBenefitAmt_ValueChanged(object sender, Telerik.Windows.RadRoutedEventArgs e)
        {
            if (calcPremiumAmt == true)
            {
                calcBenefitAmt = false;
                decimal tmpPaymentValueAmt = Convert.ToDecimal(App.Current.Properties["PaymentValueAmt"].ToString());

                App.Current.Properties["BenefitAmt"] = txtBenefitAmt.Value.ToString();
                txtPremiumAmt.Value = Decimal.Round(Convert.ToDecimal(txtBenefitAmt.Value) * tmpPaymentValueAmt / 0.95m, 2);
                App.Current.Properties["PremiumAmt"] = txtPremiumAmt.Value.ToString();
            }

        }

        private void txtPremiumAmt_ValueChanged(object sender, Telerik.Windows.RadRoutedEventArgs e)
        {
            if (calcBenefitAmt == true)
            {
                calcPremiumAmt = false;
                decimal tmpPaymentValueAmt = Convert.ToDecimal(App.Current.Properties["PaymentValueAmt"].ToString());

                App.Current.Properties["PremiumAmt"] = txtPremiumAmt.Value.ToString();
                txtBenefitAmt.Value = Decimal.Round(Convert.ToDecimal(txtPremiumAmt.Value) * 0.95m / tmpPaymentValueAmt, 2);
                App.Current.Properties["BenefitAmt"] = txtBenefitAmt.Value.ToString();
            }

        }

    }
}
