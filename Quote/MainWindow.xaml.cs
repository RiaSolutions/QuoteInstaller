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

using System.Text.RegularExpressions;
using System.Data;
using System.Data.Entity;
using Quote.Update;
using System.ComponentModel.DataAnnotations;



namespace Quote
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        private const int numberOfAttempts = 3;
        private const string dataDaseInfoName = "DataDaseInfo";
        private const string dataDaseInfoFileName = "001_Add_Table_DataDaseInfo.sql";


        public MainWindow()
        {
            InitializeComponent();
        }


        private void CheckVersion_Click(object sender, RoutedEventArgs e)
        {
            Updater updater = new Updater();
            updater.StartMonitoring();
        }

        private void CreateDB_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                using (var ctx = new AppContext())
                {
                    if (ctx.Database.Exists())
                    {
                        MessageBox.Show("Database exists");
                    }
                    else
                    {
                        MessageBox.Show("Creating db");
                        ctx.Database.Create();
                        MessageBox.Show("Created successfully, now updating");

                        string path = Assembly.GetExecutingAssembly().Location;
                        string directortyPath = System.IO.Path.GetDirectoryName(path);
                        directortyPath = directortyPath + "\\Sql\\";

                        if (!TableExists(dataDaseInfoName))
                        {
                            string scriptPath = directortyPath + dataDaseInfoFileName;
                            ExecuteQuery(scriptPath);

                            InsertSqlFileName(dataDaseInfoFileName);
                        }

                        List<string> files = System.IO.Directory.GetFiles(directortyPath, "*.sql")
                            .OrderBy(s => s)
                            .ToList();

                        List<string> sqlFileNames = GetSqlFileNames();

                        foreach (string file in files)
                        {
                            string fileName = System.IO.Path.GetFileName(file);
                            if (!sqlFileNames.Contains(fileName))
                            {
                                string scriptPath = directortyPath + fileName;
                                ExecuteQuery(scriptPath);
                                InsertSqlFileName(fileName);
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message);
            }
        }

        private bool DatabaseExists(string sqlConnectionString)
        {
            using (var context = new DbContext(sqlConnectionString))
            {
                bool result = context.Database.Exists();
                return result;
            }
        }

        private void CreateDatabase(string sqlConnectionString)
        {
            using (var context = new DbContext(sqlConnectionString))
            {
                context.Database.CreateIfNotExists();
            }
        }

        private List<string> GetSqlFileNames()
        {
            using (var context = new AppContext())
            {
                var results = context.Database.SqlQuery<string>("SELECT SqlFileName FROM DataDaseInfo").ToList();
                return results;
            }
        }

        private void InsertSqlFileName(string sqlFileName)
        {
            using (var context = new AppContext())
            {
                context.Database.ExecuteSqlCommand(
                    string.Format("INSERT INTO [dbo].[DataDaseInfo]([SqlFileName]) VALUES ('{0}')", sqlFileName));
            }
        }

        private bool TableExists(string tableName)
        {
            using (var context = new AppContext())
            {
                bool exists = context.Database
                         .SqlQuery<int?>(@"SELECT 1 FROM sys.tables AS T WHERE T.Name = @p0", tableName)
                         .SingleOrDefault() != null;
                return exists;
            }
        }

        private void ExecuteQuery(string scriptPath)
        {
            for (int attempt = 1; attempt <= numberOfAttempts; attempt++)
            {
                try
                {
                    var sql = System.IO.File.ReadAllText(scriptPath);

                    using (var context = new AppContext())
                    {
                        using (var dbContextTransaction = context.Database.BeginTransaction())
                        {
                            var lines = SplitSqlStatements(sql);
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
                    break;
                }
                catch (Exception ex)
                {
                    if (attempt >= numberOfAttempts)
                        throw ex;
                }
            }
        }

        private IEnumerable<string> SplitSqlStatements(string sqlScript)
        {
            // Split by "GO" statements
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

        private void Button_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                using (var context = new AppContext())
                {
                    context.Database.ExecuteSqlCommand("INSERT INTO [Product] (Price) VALUES (" + TboxUser.Text + ")");
                    context.SaveChanges();
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message);
            }
        }

        private void Button_Click_1(object sender, RoutedEventArgs e)
        {
            try
            {
                using (var context = new AppContext())
                {
                    var userName = context.Database.SqlQuery<int>("SELECT Price FROM [Product]").ToList().Last();
                    MessageBox.Show("last product price was = " + userName);
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message);
            }
        }

        private void Button_Click_2(object sender, RoutedEventArgs e)
        {
            try
            {
                using (var context = new AppContext())
                {
                    //context.Database.Delete();
                    //context.Database.ExecuteSqlCommand("DROP DATABASE Quote");
                    context.Database.Delete();
                    //context.SaveChanges();
                }
                MessageBox.Show("Deleted");
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message);
            }
        }
    }

    public class AppContext : DbContext
    {
        public AppContext()
            : base("Quote")
        {
        }
    }
}
