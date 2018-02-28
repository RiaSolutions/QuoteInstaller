using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.IO;
using System.Text.RegularExpressions;
using System.Data;
using System.Data.Entity;
using System.Collections;
using System.Diagnostics;
using System.Configuration.Install;
using System.Data.SqlClient;


namespace QuoteSetup.Installer
{
    [RunInstaller(true)]
    public class InstallerHelper : System.Configuration.Install.Installer
    {
        #region Fields & Constants

        private const int _numberOfAttempts = 3;
        private const string _dataDaseInfoName = "DataDaseInfo";
        private const string _dataDaseInfoFileName = "001_Add_Table_DataDaseInfo.sql";
        private const string _sqlConnectionString = @"Data source=(LocalDB)\v11.0;Initial Catalog=Quote;Integrated Security=True;";
        
        #endregion


        #region Public Methods

        public override void Install(IDictionary savedState)
        {
            base.Install(savedState);

            try
            {
                if (!DatabaseExists())
                {
                    CreateDatabase();
                }

                string path = this.Context.Parameters["assemblypath"];
                string directortyPath = Path.GetDirectoryName(path);
                directortyPath = directortyPath + "\\Sql\\";

                if (!TableExists(_dataDaseInfoName))
                {
                    string scriptPath = directortyPath + _dataDaseInfoFileName;
                    ExecuteQuery(scriptPath);

                    InsertSqlFileName(_dataDaseInfoFileName);
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
            catch (Exception ex)
            {
                throw new InstallException("Unexpected error occurred when updating the database.", ex);
            }
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
            //throw new InstallException("Uninstall runnig");
            Process application = null;
            foreach (var process in Process.GetProcesses())
            {
                if (!process.ProcessName.ToLower().Contains("quote"))
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

        #endregion


        #region Private Methods

        private List<string> GetSqlFileNames()
        {
            using (var context = new DbContext(_sqlConnectionString))
            {
                var results = context.Database.SqlQuery<string>("SELECT SqlFileName FROM DataDaseInfo").ToList();
                return results;
            }
        }

        private void InsertSqlFileName(string sqlFileName)
        {
            using (var context = new DbContext(_sqlConnectionString))
            {
                context.Database.ExecuteSqlCommand(
                    string.Format("INSERT INTO [dbo].[DataDaseInfo]([SqlFileName]) VALUES ('{0}')", sqlFileName));
            }
        }

        private bool DatabaseExists()
        {
            using (var context = new DbContext(_sqlConnectionString))
            {
                var results = context.Database.Exists();
                return results;
            }
        }

        private void CreateDatabase()
        {
            using (var context = new DbContext(_sqlConnectionString))
            {
                context.Database.CreateIfNotExists();
            }
        }

        private bool TableExists(string tableName)
        {
            using (var context = new DbContext(_sqlConnectionString))
            {
                bool exists = context.Database
                         .SqlQuery<int?>(@"SELECT 1 FROM sys.tables AS T WHERE T.Name = @p0", tableName)
                         .SingleOrDefault() != null;
                return exists;
            }
        }

        private void ExecuteQuery(string scriptPath)
        {
            for (int attempt = 1; attempt <= _numberOfAttempts; attempt++)
            {
                try
                {
                    var sql = System.IO.File.ReadAllText(scriptPath);

                    using (var context = new DbContext(_sqlConnectionString))
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
                    if (attempt >= _numberOfAttempts)
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
