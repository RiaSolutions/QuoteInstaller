using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using EO.Pdf;
using System.Windows.Controls;

namespace BusinessLogicLayer
{
    public class QuoteIllustration
    {
        private string _illustrationReportName;
        private string _settlementReportName;

        // Development
        //private const string _reportFolder = @"C:\Users\bbopp\Documents\Visual Studio 2013\Projects\StlmtQuote\StlmQuoteWPF\Reports\";
        private const string _reportFolder = @"C:\Users\bbopp\Source\Repos\QuoteInstaller2\StlmQuoteWPF\Reports\";
        // Production
        //private const string _reportFolder = @"C:\Program Files (x86)\Independent Insurance Group\Independent Quoting System\Reports\";
        
        private const string _templateIllustrationReport = _reportFolder + @"QuoteTemplate.pdf";
        private const string _templateSettlementReport = _reportFolder + @"SettlementTemplate.pdf";

        public string IllustrationReportName
        {
            get { return _illustrationReportName; }
            set { _illustrationReportName = value; }
        }
        public string SettlementReportName
        {
            get { return _settlementReportName; }
            set { _settlementReportName = value; }
        }

        public QuoteIllustration()
        {
            string tmpTimeStamp = DateTime.Now.ToString("MM-dd-yyyy_hh-mm-ss");
            IllustrationReportName = _reportFolder + "Illustration_" + tmpTimeStamp + ".pdf";
            SettlementReportName = _reportFolder + "Settlement_" + tmpTimeStamp + ".pdf";

            EO.Pdf.Runtime.AddLicense(
                "habCnrWfWZekzdrgpePzCOmMQ5ekscu7qOno9h3Ip93zsQ/grdzBs+Gua6qz" +
                "w9uwcJmkBCDhfu/0+h3krLj4zs21aKm3wN2vaq+msSHkq+rtABm8W6i7s8uu" +
                "d4SOscufWbP3+hLtmuv5AxC9r+DV6vWua+HcCgDCj8Pa+frWcsTJ+Oi8dab3" +
                "+hLtmuv5AxC9RoHAwBfonNzyBBC9RoF14+30EO2s3MKetZ9Zl6TNF+ic3PIE" +
                "EMidtbjB3LRysLjK3bRys7P9FOKe5ff29ON3hI6xy59Zs/D6DuSn6un26bto" +
                "4+30EO2s3OnPuIlZl6Sx5+Cl4/MI6YxDl6Sxy59Zl6TNDOOdl/gKG+R2mcng" +
                "2c+d3aaxIeSr6u0AGbxbqLu/26FZ");

        }

        public void CreateQuoteIllustrationReport(int stlmtBrokerID, string annuitantName, string genderAndAgeLabel, string genderAndAge, DateTime quoteDate
            , DateTime purchaseDate, string rateVersion, DataGrid dgBenefits)
        {
            PdfDocument reportDoc;

            BusinessLogicLayer.Broker brk = new Broker();
            brk.GetBroker(stlmtBrokerID);

            //string path = System.IO.Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().GetName().CodeBase);
            //string tmpForm = System.IO.Path.Combine(path + @"\Reports", "QuoteTemplate.pdf");

            //tmpForm = @"C:\Users\bbopp\Documents\Visual Studio 2013\Projects\StlmtQuote\StlmQuoteWPF\Reports\QuoteTemplate.pdf";
            //tmpForm = @"C:\Program Files (x86)\Independent Insurance Group\Independent Quoting System\Reports\QuoteTemplate.pdf";

            reportDoc = new PdfDocument(_templateIllustrationReport);

            // Page 1 *************************************************************************************
            PdfField BrokerageName = reportDoc.Fields["BrokerageName"];
            BrokerageName.Value = brk.EntityName;

            PdfField BrokerAddress1 = reportDoc.Fields["BrokerAddress1"];
            BrokerAddress1.Value = brk.AddrLine1;

            PdfField BrokerAddress2 = reportDoc.Fields["BrokerAddress2"];
            BrokerAddress2.Value = brk.City + ", " + brk.StateCode + ", " + brk.ZipCode5;

            PdfField PreparedBy = reportDoc.Fields["PreparedBy"];
            PreparedBy.Value = brk.FirstName + " " + brk.LastName;

            PdfField PreparedFor = reportDoc.Fields["PreparedFor"];
            PreparedFor.Value = annuitantName;

            PdfField GenderAgeLabel = reportDoc.Fields["GenderAgeLabel"];
            GenderAgeLabel.Value = genderAndAgeLabel;

            PdfField GenderAge = reportDoc.Fields["GenderAge"];
            GenderAge.Value = genderAndAge;

            PdfField QuoteDate = reportDoc.Fields["QuoteDate"];
            QuoteDate.Value = quoteDate.ToShortDateString();

            PdfField PurchaseDate = reportDoc.Fields["PurchaseDate"];
            PurchaseDate.Value = purchaseDate.ToShortDateString();

            PdfField RateVersion = reportDoc.Fields["RateVersion"];
            RateVersion.Value = rateVersion;

            PdfField BenefitType1 = reportDoc.Fields["BenefitType1"];
            PdfField BenefitPeriod1 = reportDoc.Fields["BenefitPeriod1"];
            PdfField Amount1 = reportDoc.Fields["Amount1"];
            PdfField Mode1 = reportDoc.Fields["Mode1"];
            PdfField Premium1 = reportDoc.Fields["Premium1"];
            PdfField BenefitType2 = reportDoc.Fields["BenefitType2"];
            PdfField BenefitPeriod2 = reportDoc.Fields["BenefitPeriod2"];
            PdfField Amount2 = reportDoc.Fields["Amount2"];
            PdfField Mode2 = reportDoc.Fields["Mode2"];
            PdfField Premium2 = reportDoc.Fields["Premium2"];
            PdfField BenefitType3 = reportDoc.Fields["BenefitType3"];
            PdfField BenefitPeriod3 = reportDoc.Fields["BenefitPeriod3"];
            PdfField Amount3 = reportDoc.Fields["Amount3"];
            PdfField Mode3 = reportDoc.Fields["Mode3"];
            PdfField Premium3 = reportDoc.Fields["Premium3"];
            PdfField BenefitType4 = reportDoc.Fields["BenefitType4"];
            PdfField BenefitPeriod4 = reportDoc.Fields["BenefitPeriod4"];
            PdfField Amount4 = reportDoc.Fields["Amount4"];
            PdfField Mode4 = reportDoc.Fields["Mode4"];
            PdfField Premium4 = reportDoc.Fields["Premium4"];
            PdfField BenefitType5 = reportDoc.Fields["BenefitType5"];
            PdfField BenefitPeriod5 = reportDoc.Fields["BenefitPeriod5"];
            PdfField Amount5 = reportDoc.Fields["Amount5"];
            PdfField Mode5 = reportDoc.Fields["Mode5"];
            PdfField Premium5 = reportDoc.Fields["Premium5"];

            PdfField Footer = reportDoc.Fields["Footer"];
            string tmpFooter;
            tmpFooter = "Expected values are calculated using the annuitant’s actual age and life expectancy based on the 1983(a) IAM table.\n";
            tmpFooter = tmpFooter + "This illustration will expire on " + DateTime.Now.AddDays(7).ToString("MM/dd/yyyy") + " or the last day of \n";
            tmpFooter = tmpFooter + "This is an illustration only and is subject to approval by Independent Life, inclusive of the submission of all required documents and adherence to quoting restrictions as described in the IL Broker Manual & Underwriting Guidelines.";
            Footer.Value = tmpFooter;
            //Footer.Font = new EO.Pdf.Drawing.PdfFont("Adobe Arabic Italic", 10);
            Footer.Font.Italic = true;


            int benefitNum = 1;
            decimal totalPremium = 0.0m;
            string tmpBenefitPeriod = "";
            DateTime endDate;

            foreach (System.Data.DataRowView dr in dgBenefits.ItemsSource)
            {
                switch (dr[3].ToString())
                {
                    case "Life":
                        tmpBenefitPeriod = Convert.ToDateTime(dr[6].ToString()).ToString("MM/dd/yyyy") + " - for Life";
                        break;
                    case "Period Certain":
                        endDate = Convert.ToDateTime(dr[6].ToString());
                        endDate = endDate.AddYears(Convert.ToInt16(dr[7].ToString()));
                        endDate = endDate.AddMonths(Convert.ToInt16(dr[8].ToString()));
                        tmpBenefitPeriod = Convert.ToDateTime(dr[6].ToString()).ToString("MM/dd/yyyy") + " - " + endDate.ToShortDateString();
                        break;
                    case "Temporary Life":
                        endDate = Convert.ToDateTime(dr[6].ToString());
                        endDate = endDate.AddYears(Convert.ToInt16(dr[7].ToString()));
                        endDate = endDate.AddMonths(Convert.ToInt16(dr[8].ToString()));
                        tmpBenefitPeriod = Convert.ToDateTime(dr[6].ToString()).ToString("MM/dd/yyyy") + " - " + endDate.ToShortDateString();
                        break;
                    case "Lump Sum":
                        tmpBenefitPeriod = Convert.ToDateTime(dr[6].ToString()).ToString("MM/dd/yyyy");
                        break;
                    default:
                        break;
                }

                switch (benefitNum)
                {
                    case 1:
                        BenefitType1.Value = dr[3].ToString();
                        BenefitPeriod1.Value = tmpBenefitPeriod;
                        Amount1.Value = String.Format("{0:C}", Convert.ToDecimal(dr[4].ToString()));
                        Mode1.Value = dr[5].ToString();
                        Premium1.Value = String.Format("{0:C}", Convert.ToDecimal(dr[10].ToString()));
                        break;
                    case 2:
                        BenefitType2.Value = dr[3].ToString();
                        BenefitPeriod2.Value = tmpBenefitPeriod;
                        Amount2.Value = String.Format("{0:C}", Convert.ToDecimal(dr[4].ToString()));
                        Mode2.Value = dr[5].ToString();
                        Premium2.Value = String.Format("{0:C}", Convert.ToDecimal(dr[10].ToString()));
                        break;
                    case 3:
                        BenefitType3.Value = dr[3].ToString();
                        BenefitPeriod3.Value = tmpBenefitPeriod;
                        Amount3.Value = String.Format("{0:C}", Convert.ToDecimal(dr[4].ToString()));
                        Mode3.Value = dr[5].ToString();
                        Premium3.Value = String.Format("{0:C}", Convert.ToDecimal(dr[10].ToString()));
                        break;
                    case 4:
                        BenefitType4.Value = dr[3].ToString();
                        BenefitPeriod4.Value = tmpBenefitPeriod;
                        Amount4.Value = String.Format("{0:C}", Convert.ToDecimal(dr[4].ToString()));
                        Mode4.Value = dr[5].ToString();
                        Premium4.Value = String.Format("{0:C}", Convert.ToDecimal(dr[10].ToString()));
                        break;
                    case 5:
                        BenefitType5.Value = dr[3].ToString();
                        BenefitPeriod5.Value = tmpBenefitPeriod;
                        Amount5.Value = String.Format("{0:C}", Convert.ToDecimal(dr[4].ToString()));
                        Mode5.Value = dr[5].ToString();
                        Premium5.Value = String.Format("{0:C}", Convert.ToDecimal(dr[10].ToString()));
                        break;
                    default:
                        break;
                }
                benefitNum++;
                totalPremium = totalPremium + Convert.ToDecimal(dr[10].ToString());
                tmpBenefitPeriod = "Not Assigned";
            }

            PdfField TotalPremium = reportDoc.Fields["TotalPremium"];
            TotalPremium.Value = String.Format("{0:C}", totalPremium);

            PdfField AssignmentFee = reportDoc.Fields["AssignmentFee"];
            AssignmentFee.Value = String.Format("{0:C}", 750.0);

            PdfField TotalCost = reportDoc.Fields["TotalCost"];
            TotalCost.Value = String.Format("{0:C}", totalPremium + 750.0m);

            PdfDocument finalDoc = new PdfDocument();

            finalDoc = reportDoc.Clone();
            //finalDoc = proposalDoc;

            //finalDoc.Security.Permissions = PdfDocumentPermissions.Printing;
            //finalDoc.Security.Permissions = PdfDocumentPermissions.All | PdfDocumentPermissions.HighQualityPrinting;
            finalDoc.Security.Permissions = PdfDocumentPermissions.Printing | PdfDocumentPermissions.HighQualityPrinting;
            //finalDoc.Security.Permissions = PdfDocumentPermissions.CopyingContents| PdfDocumentPermissions.CopyingContentsForAccessibility;

            
            //string thisFileName;

            //thisFileName = "~/App_Data/SPDA_Proposal_" + thisProposal.DateCreated.ToString("dd-MM-yyyy_hh-mm-ss") + ".pdf";
            //thisFileName = @"C:\Users\bbopp\Documents\Visual Studio 2013\Projects\StlmtQuote\StlmQuoteWPF\Reports\test_" + DateTime.Now.ToString("MM-dd-yyyy_hh-mm-ss") + ".pdf";
            //thisFileName = @"C:\Program Files (x86)\Independent Insurance Group\Independent Quoting System\Reports\test_" + DateTime.Now.ToString("MM-dd-yyyy_hh-mm-ss") + ".pdf";



            finalDoc.Save(IllustrationReportName);

        }

//        public void CreateSettlementReport(int stlmtBrokerID, string annuitantName, string genderAndAge, DateTime quoteDate
//            , DateTime purchaseDate, string rateVersion, DataGrid dgBenefits)


        public void CreateSettlementReport(int stlmtBrokerID, string annuitantName, string genderAndAgeLabel, string genderAndAge, DateTime quoteDate
            , DateTime purchaseDate, string rateVersion, DataGrid dgBenefits, int quoteID)
        {

            decimal irr = 0.0m;
            decimal equivalentCash = 0.0m;
            decimal equivalentCashPct = 0.04m;
            DataAccessLayer.Report rpt = new DataAccessLayer.Report();
            rpt.CreateSettlementReportData(quoteID, ref irr, ref equivalentCash);

            PdfDocument reportDoc;

            BusinessLogicLayer.Broker brk = new Broker();
            brk.GetBroker(stlmtBrokerID);

            reportDoc = new PdfDocument(_templateSettlementReport);

            // Page 1 *************************************************************************************
            PdfField BrokerageName = reportDoc.Fields["BrokerageName"];
            BrokerageName.Value = brk.EntityName;

            PdfField BrokerAddress1 = reportDoc.Fields["BrokerAddress1"];
            BrokerAddress1.Value = brk.AddrLine1;

            PdfField BrokerAddress2 = reportDoc.Fields["BrokerAddress2"];
            BrokerAddress2.Value = brk.City + ", " + brk.StateCode + ", " + brk.ZipCode5;

            PdfField PreparedBy = reportDoc.Fields["PreparedBy"];
            PreparedBy.Value = brk.FirstName + " " + brk.LastName;

            PdfField PreparedFor = reportDoc.Fields["PreparedFor"];
            PreparedFor.Value = annuitantName;

            PdfField GenderAgeLabel = reportDoc.Fields["GenderAgeLabel"];
            GenderAgeLabel.Value = genderAndAgeLabel;

            PdfField GenderAge = reportDoc.Fields["GenderAge"];
            GenderAge.Value = genderAndAge;

            PdfField QuoteDate = reportDoc.Fields["QuoteDate"];
            QuoteDate.Value = quoteDate.ToShortDateString();

            PdfField PurchaseDate = reportDoc.Fields["PurchaseDate"];
            PurchaseDate.Value = purchaseDate.ToShortDateString();

            PdfField RateVersion = reportDoc.Fields["RateVersion"];
            RateVersion.Value = rateVersion;

            PdfField BenefitDesc1 = reportDoc.Fields["BenefitDesc1"];
            PdfField GuaranteedAmt1 = reportDoc.Fields["GuaranteedAmt1"];
            PdfField ExpectedAmt1 = reportDoc.Fields["ExpectedAmt1"];
            PdfField CostAmt1 = reportDoc.Fields["CostAmt1"];

            PdfField BenefitDesc2 = reportDoc.Fields["BenefitDesc2"];
            PdfField GuaranteedAmt2 = reportDoc.Fields["GuaranteedAmt2"];
            PdfField ExpectedAmt2 = reportDoc.Fields["ExpectedAmt2"];
            PdfField CostAmt2 = reportDoc.Fields["CostAmt2"];

            PdfField BenefitDesc3 = reportDoc.Fields["BenefitDesc3"];
            PdfField GuaranteedAmt3 = reportDoc.Fields["GuaranteedAmt3"];
            PdfField ExpectedAmt3 = reportDoc.Fields["ExpectedAmt3"];
            PdfField CostAmt3 = reportDoc.Fields["CostAmt3"];

            PdfField BenefitDesc4 = reportDoc.Fields["BenefitDesc4"];
            PdfField GuaranteedAmt4 = reportDoc.Fields["GuaranteedAmt4"];
            PdfField ExpectedAmt4 = reportDoc.Fields["ExpectedAmt4"];
            PdfField CostAmt4 = reportDoc.Fields["CostAmt4"];

            PdfField BenefitDesc5 = reportDoc.Fields["BenefitDesc5"];
            PdfField GuaranteedAmt5 = reportDoc.Fields["GuaranteedAmt5"];
            PdfField ExpectedAmt5 = reportDoc.Fields["ExpectedAmt5"];
            PdfField CostAmt5 = reportDoc.Fields["CostAmt5"];

            int benefitNum = 1;
            decimal subTotalGuranteedAmt = 0.0m;
            decimal subTotalExpectedBenefitAmt = 0.0m;
            decimal subTotalCostAmt = 0.0m;
            string tmpBenefitDesc = "";
            DateTime endDate;

            foreach (System.Data.DataRowView dr in dgBenefits.ItemsSource)
            {
                decimal benefitAmt = Convert.ToDecimal(dr[4].ToString());
                string paymentMode = dr[5].ToString();
                int certainYears = Convert.ToInt16(dr[7].ToString());

                endDate = Convert.ToDateTime(dr[6].ToString());
                //endDate = endDate.AddYears(Convert.ToInt16(dr[7].ToString()));
                //endDate = endDate.AddMonths(Convert.ToInt16(dr[8].ToString()));
                endDate = endDate.AddMonths((Convert.ToInt16(dr[7].ToString()) * 12) + (Convert.ToInt16(dr[8].ToString())) - 1);

                switch (dr[3].ToString())
                {
                    case "Life":
                        tmpBenefitDesc = "Life with Certain Period Annuity - " + String.Format("{0:C}", benefitAmt) + " for life, payable " + paymentMode + ", "
                            + " guaranteed for " + certainYears.ToString() + " year(s), "
                            + "beginning on " + Convert.ToDateTime(dr[6].ToString()).ToShortDateString() + ", "
                            + "with the last guaranteed payment on " + endDate.ToShortDateString();
                        break;
                    case "Period Certain":
                        tmpBenefitDesc = "Period Certain Annuity - " + String.Format("{0:C}", benefitAmt) + " payable " + paymentMode + ", "
                            + " guaranteed for " + certainYears.ToString() + " year(s), "
                            + "beginning on " + Convert.ToDateTime(dr[6].ToString()).ToShortDateString() + ", "
                            + "with the last guaranteed payment on " + endDate.ToShortDateString();
                        break;
                    case "Temporary Life":
                        tmpBenefitDesc = "Temporary Life Annuity - " + String.Format("{0:C}", benefitAmt) + " paid if living, payable " + paymentMode + ", "
                            + "beginning on " + Convert.ToDateTime(dr[6].ToString()).ToShortDateString() 
                            + " for a maximum of " + certainYears.ToString() + " year(s).";
                        break;
                    case "Lump Sum":
                        tmpBenefitDesc = "Guaranteed Lump Sum - " + String.Format("{0:C}", benefitAmt)
                            + " paid on " + Convert.ToDateTime(dr[6].ToString()).ToShortDateString();
                        break;
                    default:
                        break;
                }

                decimal guaranteedAmt = Convert.ToDecimal(dr[13].ToString()) * benefitAmt;
                decimal expectedAmt = Convert.ToDecimal(dr[12].ToString()) * benefitAmt;
                decimal costAmt = Convert.ToDecimal(dr[10].ToString());

                switch (benefitNum)
                {
                    case 1:
                        BenefitDesc1.Value = tmpBenefitDesc;
                        GuaranteedAmt1.Value = String.Format("{0:C}", guaranteedAmt);
                        ExpectedAmt1.Value = String.Format("{0:C}", expectedAmt);
                        CostAmt1.Value = String.Format("{0:C}", costAmt);
                        break;
                    case 2:
                        BenefitDesc2.Value = tmpBenefitDesc;
                        GuaranteedAmt2.Value = String.Format("{0:C}", guaranteedAmt);
                        ExpectedAmt2.Value = String.Format("{0:C}", expectedAmt);
                        CostAmt2.Value = String.Format("{0:C}", costAmt);
                        break;
                    case 3:
                        BenefitDesc3.Value = tmpBenefitDesc;
                        GuaranteedAmt3.Value = String.Format("{0:C}", guaranteedAmt);
                        ExpectedAmt3.Value = String.Format("{0:C}", expectedAmt);
                        CostAmt3.Value = String.Format("{0:C}", costAmt);
                        break;
                    case 4:
                        BenefitDesc4.Value = tmpBenefitDesc;
                        GuaranteedAmt4.Value = String.Format("{0:C}", guaranteedAmt);
                        ExpectedAmt4.Value = String.Format("{0:C}", expectedAmt);
                        CostAmt4.Value = String.Format("{0:C}", costAmt);
                        break;
                    case 5:
                        BenefitDesc5.Value = tmpBenefitDesc;
                        GuaranteedAmt5.Value = String.Format("{0:C}", guaranteedAmt);
                        ExpectedAmt5.Value = String.Format("{0:C}", expectedAmt);
                        CostAmt5.Value = String.Format("{0:C}", costAmt);
                        break;
                    default:
                        break;
                }
                benefitNum++;
                subTotalGuranteedAmt = subTotalGuranteedAmt + guaranteedAmt;
                subTotalExpectedBenefitAmt = subTotalExpectedBenefitAmt + expectedAmt;
                subTotalCostAmt = subTotalCostAmt + costAmt;
                tmpBenefitDesc = "Not Assigned";
            }

            //PdfField SubTotalGuaranteedAmt = reportDoc.Fields["SubTotalGuaranteedAmt"];
            //SubTotalGuaranteedAmt.Value = String.Format("{0:C}", subTotalGuranteedAmt);

            //PdfField SubTotalExpectedAmt = reportDoc.Fields["SubTotalExpectedAmt"];
            //SubTotalExpectedAmt.Value = String.Format("{0:C}", subTotalExpectedBenefitAmt);

            //PdfField SubTotalCostAmt = reportDoc.Fields["SubTotalCostAmt"];
            //SubTotalCostAmt.Value = String.Format("{0:C}", subTotalCostAmt);

            PdfField AnnuityCostAmt = reportDoc.Fields["AnnuityCostAmt"];
            AnnuityCostAmt.Value = String.Format("{0:C}", subTotalCostAmt);

            PdfField AssignmentFeeAmt = reportDoc.Fields["AssignmentFeeAmt"];
            AssignmentFeeAmt.Value = String.Format("{0:C}", 750.0m);

            PdfField TotalGuaranteedAmt = reportDoc.Fields["TotalGuaranteedAmt"];
            TotalGuaranteedAmt.Value = String.Format("{0:C}", subTotalGuranteedAmt);

            PdfField TotalExpectedAmt = reportDoc.Fields["TotalExpectedAmt"];
            TotalExpectedAmt.Value = String.Format("{0:C}", subTotalExpectedBenefitAmt);

            PdfField TotalCostAmt = reportDoc.Fields["TotalCostAmt"];
            TotalCostAmt.Value = String.Format("{0:C}", subTotalCostAmt + 750.0m);

            PdfField EquivalentCashAmt = reportDoc.Fields["EquivalentCashAmt"];
            EquivalentCashAmt.Value = String.Format("{0:C}", equivalentCash);

            PdfField EquivalentCashPct = reportDoc.Fields["EquivalentCashPct"];
            EquivalentCashPct.Value = "@ " + equivalentCashPct.ToString("P");

            PdfField IRR = reportDoc.Fields["IRR"];
            IRR.Value = irr.ToString("P");

            PdfField Footer1 = reportDoc.Fields["Footer1"];
            PdfField Footer2 = reportDoc.Fields["Footer2"];
            PdfField Footer3 = reportDoc.Fields["Footer3"];

            Footer1.Value = "Expected values are calculated using the annuitant’s actual age and life expectancy based on the 1983(a) IAM table.";
            Footer2.Value = "This illustration will expire on " + DateTime.Now.AddDays(7).ToString("MM/dd/yyyy") + " Rate Series: " + rateVersion;
            Footer3.Value = "This is an illustration only and is subject to approval by Independent Life, inclusive of the submission of all required documents and adherence to quoting restrictions as described in the IL Broker Manual & Underwriting Guidelines.";
            //Footer1.Font = new EO.Pdf.Drawing.PdfFont("Adobe Arabic Italic", 10);
            Footer1.Font.Italic = true;
            Footer2.Font.Italic = true;
            Footer3.Font.Italic = true;

            PdfDocument finalDoc = new PdfDocument();

            finalDoc = reportDoc.Clone();

            finalDoc.Security.Permissions = PdfDocumentPermissions.Printing | PdfDocumentPermissions.HighQualityPrinting;

            finalDoc.Save(SettlementReportName);

        }
    }
}
