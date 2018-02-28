using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;
using System.Linq;
using System.Reflection;
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

using Microsoft.SqlServer.Management.Smo;
using Microsoft.SqlServer.Management.Common;
using System.Text.RegularExpressions;
using System.Data;
using System.Data.Entity;



namespace WpfSetupTest
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        public MainWindow()
        {
            InitializeComponent();
        }

        //private void CreateDB_Click(object sender, RoutedEventArgs e)
        //{
        //    string sqlConnectionString = @"Data Source=.;Initial Catalog=master;Integrated Security=SSPI";
        //    string path = Assembly.GetExecutingAssembly().Location;
        //    string directortyPath = System.IO.Path.GetDirectoryName(path);
        //    string script = File.ReadAllText(directortyPath + "\\Sql\\CeateTestDb.sql");

        //    MessageBox.Show(script);

        //    SqlConnection conn = new SqlConnection(sqlConnectionString);
        //    Server server = new Server(new ServerConnection(conn));

        //    server.ConnectionContext.ExecuteNonQuery(script);
        //}

        //private void CreateDB_Click(object sender, RoutedEventArgs e)
        //{
        //    string sqlConnectionString = @"Data Source=.;Initial Catalog=master;Integrated Security=SSPI";
        //    string path = Assembly.GetExecutingAssembly().Location;
        //    string directortyPath = System.IO.Path.GetDirectoryName(path);
        //    string scriptPath = directortyPath + "\\Sql\\CeateTestDb.sql";

        //    string script = File.ReadAllText(scriptPath);

        //    SqlConnection conn = new SqlConnection(sqlConnectionString);

        //    Server server = new Server(new ServerConnection(conn));

        //    server.ConnectionContext.ExecuteNonQuery(script);



        //    //using (SqlConnection conn = new SqlConnection(sqlConnectionString))
        //    //{
        //    //    conn.Open();
        //    //    string sqlCommandFilePath = scriptPath;
        //    //    if (File.Exists(sqlCommandFilePath))
        //    //    {
        //    //        
        //    //        using (SqlCommand cmd = new SqlCommand(script, conn))
        //    //        {
        //    //            int affectedRows = cmd.ExecuteNonQuery();
        //    //        }
        //    //    }

        //    //}
        //}


        private void CreateDB_Click(object sender, RoutedEventArgs e)
        {
            string path = Assembly.GetExecutingAssembly().Location;
            string directortyPath = System.IO.Path.GetDirectoryName(path);

            //string scriptPath = directortyPath + "\\Sql\\001_CeateDb.sql";
            //string sqlConnectionString = @"Data Source=.;Initial Catalog=master;Integrated Security=SSPI";

            //ExecuteQuery1(scriptPath, sqlConnectionString);


            string scriptPath2 = directortyPath + "\\Sql\\002_CeateTable.sql";
            string sqlConnectionString2 = @"Data Source=.;Initial Catalog=Test2;Integrated Security=SSPI";

            ExecuteQuery2(scriptPath2, sqlConnectionString2);


            //using (var ctx = new SchoolDBEntities())
            //{
            //    var studentList = ctx.Students
            //                        .SqlQuery("Select * from Students")
            //                        .ToList<Student>();
            //}

            //ExecuteSql(sqlConnectionString, scriptPath);
        }

        private void CreateDataBase(string scriptPath, string sqlConnectionString)
        {
            var sql = System.IO.File.ReadAllText(scriptPath);
            var context = new DbContext(sqlConnectionString);

            context.Database.ExecuteSqlCommand(TransactionalBehavior.DoNotEnsureTransaction, sql);
        }

        private void ExecuteQuery2(string scriptPath, string sqlConnectionString)
        {
            var sql = System.IO.File.ReadAllText(scriptPath);

            using (var context = new DbContext(sqlConnectionString))
            {
                context.Database.CreateIfNotExists();

                //Regex regex = new Regex("^GO", RegexOptions.IgnoreCase | RegexOptions.Multiline);
                //string[] lines = regex.Split(sql);

                var lines = SplitSqlStatements(sql);

                using (var dbContextTransaction = context.Database.BeginTransaction())
                {
                    foreach (string line in lines)
                    {
                        if (line.Length > 0)
                        {
                            try
                            {
                                context.Database.ExecuteSqlCommand(line);
                            }
                            catch (Exception ex)
                            {
                                dbContextTransaction.Rollback();
                                throw ex;
                            }
                        }
                    }
                    context.SaveChanges();
                    dbContextTransaction.Commit(); 
                }
            }
        }

        private IEnumerable<string> SplitSqlStatements(string sqlScript)
        {
            // Split by "GO" statements
            //var pattern = @"^[\t ]*GO[\t ]*\d*[\t ]*(?:--.*)?$";
            var pattern = @"^GO";

            var statements = Regex.Split(
                    sqlScript,
                    pattern,
                    RegexOptions.Multiline |
                    RegexOptions.IgnorePatternWhitespace |
                    RegexOptions.IgnoreCase);

            // Remove empties, trim, and return
            return statements
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Select(x => x.Trim(' ', '\r', '\n'));
        }


        //private void CreateDB_Click(object sender, RoutedEventArgs e)
        //{
        //    string sqlConnectionString = @"Data Source=.;Initial Catalog=master;Integrated Security=SSPI";

        //    string path = Assembly.GetExecutingAssembly().Location;
        //    string directortyPath = System.IO.Path.GetDirectoryName(path);
        //    string scriptPath = directortyPath + "\\Sql\\CeateTestDb.sql";

        //    ExecuteSql(sqlConnectionString, scriptPath);
        //}




        public void ExecuteSql(string sqlConnectionString, string sqlFile)
        {
            SqlConnection connection = new SqlConnection(sqlConnectionString);
            connection.Open();

            string sql = "";

            using (FileStream strm = File.OpenRead(sqlFile))
            {
                StreamReader reader = new StreamReader(strm);
                sql = reader.ReadToEnd();
            }


            Regex regex = new Regex("^GO", RegexOptions.IgnoreCase | RegexOptions.Multiline);
            string[] lines = regex.Split(sql);

            SqlTransaction transaction = connection.BeginTransaction();
            using (SqlCommand cmd = connection.CreateCommand())
            {
                cmd.Connection = connection;
                cmd.Transaction = transaction;

                foreach (string line in lines)
                {
                    if (line.Length > 0)
                    {
                        cmd.CommandText = line;
                        cmd.CommandType = CommandType.Text;

                        try
                        {
                            cmd.ExecuteNonQuery();
                        }
                        catch (SqlException)
                        {
                            transaction.Rollback();
                            throw;
                        }
                    }
                }
            }
            transaction.Commit();
        }
    }
}
