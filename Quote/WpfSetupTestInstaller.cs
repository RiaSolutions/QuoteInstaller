using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.Configuration.Install;
using System.Data.SqlClient;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.IO;
using System.Text.RegularExpressions;
using System.Data;
using System.Data.Entity;
using System.Linq;


namespace WpfSetupTest
{
    [RunInstaller(true)]
    public partial class WpfSetupTestInstaller : System.Configuration.Install.Installer
    {
        #region Fields & Constants

        private const int numberOfAttempts = 3;
        private const string dataDaseInfoName = "DataDaseInfo";
        private const string dataDaseInfoFileName = "001_Add_Table_DataDaseInfo.sql";

        #endregion


        #region Constructor

        public WpfSetupTestInstaller()
        {
            InitializeComponent();
        }

        #endregion


        #region Public Methods

        public override void Install(IDictionary savedState)
        {
            base.Install(savedState);
            //Add custom code here
        }

        public override void Rollback(IDictionary savedState)
        {
            base.Rollback(savedState);
            //Add custom code here
        }

        public override void Commit(IDictionary savedState)
        {
            base.Commit(savedState);
            //Add custom code here
        }

        public override void Uninstall(IDictionary savedState)
        {
            Process application = null;
            foreach (var process in Process.GetProcesses())
            {
                if (!process.ProcessName.ToLower().Contains("creatinginstaller"))
                    continue;
                application = process;
                break;
            }

            if (application != null && application.Responding)
            {
                application.Kill();
                base.Uninstall(savedState);
            }
        }

        protected override void OnAfterInstall(IDictionary savedState)
        {
            base.OnAfterInstall(savedState);

            try
            {
                string sqlConnectionString = @"Data Source=.;Initial Catalog=Amr;Integrated Security=SSPI";

                if (!DatabaseExists(sqlConnectionString))
                {
                    CreateDatabase(sqlConnectionString);
                }

                string path = this.Context.Parameters["assemblypath"];
                string directortyPath = Path.GetDirectoryName(path);
                directortyPath = directortyPath + "\\Sql\\";

                if (!TableExists(sqlConnectionString, dataDaseInfoName))
                {
                    string scriptPath = directortyPath + dataDaseInfoFileName;
                    ExecuteQuery(scriptPath, sqlConnectionString);

                    InsertSqlFileName(sqlConnectionString, dataDaseInfoFileName);
                }

                List<string> files = System.IO.Directory.GetFiles(directortyPath, "*.sql")
                        .OrderBy(s => s)
                        .ToList();

                List<string> sqlFileNames = GetSqlFileNames(sqlConnectionString);

                foreach (string file in files)
                {
                    string fileName = System.IO.Path.GetFileName(file);
                    if (!sqlFileNames.Contains(fileName))
                    {
                        string scriptPath = directortyPath + fileName;
                        ExecuteQuery(scriptPath, sqlConnectionString);
                        InsertSqlFileName(sqlConnectionString, fileName);
                    }
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "Error", MessageBoxButton.OK, MessageBoxImage.Error); ;
            }
        }

        #endregion


        #region Private Methods

        private List<string> GetSqlFileNames(string sqlConnectionString)
        {
            using (var context = new DbContext(sqlConnectionString))
            {
                var results = context.Database.SqlQuery<string>("SELECT SqlFileName FROM DataDaseInfo").ToList();
                return results;
            }
        }

        private void InsertSqlFileName(string sqlConnectionString, string sqlFileName)
        {
            using (var context = new DbContext(sqlConnectionString))
            {
                context.Database.ExecuteSqlCommand(
                    string.Format("INSERT INTO [dbo].[DataDaseInfo]([SqlFileName]) VALUES ('{0}')", sqlFileName));
            }
        }

        private bool DatabaseExists(string sqlConnectionString)
        {
            using (var context = new DbContext(sqlConnectionString))
            {
                var results = context.Database.Exists();
                return results;
            }
        }

        private void CreateDatabase(string sqlConnectionString)
        {
            using (var context = new DbContext(sqlConnectionString))
            {
                context.Database.CreateIfNotExists();
            }
        }

        private bool TableExists(string sqlConnectionString, string tableName)
        {
            using (var context = new DbContext(sqlConnectionString))
            {
                bool exists = context.Database
                         .SqlQuery<int?>(@"SELECT 1 FROM sys.tables AS T WHERE T.Name = @p0", tableName)
                         .SingleOrDefault() != null;
                return exists;
            }
        }

        private void ExecuteQuery(string scriptPath, string sqlConnectionString)
        {
            for (int attempt = 1; attempt <= numberOfAttempts; attempt++)
            {
                try
                {
                    var sql = System.IO.File.ReadAllText(scriptPath);

                    using (var context = new DbContext(sqlConnectionString))
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

        #endregion
    }
}
