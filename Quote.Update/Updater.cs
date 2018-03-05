using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Security.Principal;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;


namespace Quote.Update
{
    public class Updater
    {
        #region Constants

        /// <summary>
        /// The default configuration file
        /// </summary>
        public const string DefaultConfigFile = "Manifest/update.xml";

        public const string UpgradeFolderName = "QuoteUpgrade";

        public const string SetupFileName = "setup.exe";

        #endregion


        #region Fields

        private volatile bool _updating;
        private Timer _timer;
        private Manifest _remoteConfig;
        private Manifest _localConfig;

        public FileInfo configFile { get; set; }

        #endregion


        #region Constructor

        /// <summary>
        /// Initializes a new instance of the <see cref="Updater"/> class.
        /// </summary>
        public Updater()
        {
            try
            {
                Log.Write("{0} started.", MethodInfoHelper.GetCurrentMethodName());

                var configFile = new FileInfo(DefaultConfigFile);
                Log.Write("Initializing using file '{0}'.", configFile.FullName);

                if (!configFile.Exists)
                    throw new Exception(string.Format("Config file '{0}' does not exist, stopping.", configFile.Name));

                string data = File.ReadAllText(configFile.FullName);
                _localConfig = new Manifest(data);
            }
            catch (Exception ex)
            {
                Log.Write("{0} failed. {1}", MethodInfoHelper.GetCurrentMethodName(), ex.Message);
            }
            finally
            {
                Log.Write("{0} ended.", MethodInfoHelper.GetCurrentMethodName());
            }

        }

        #endregion

        #region Events

        /// <summary>
        /// Occurs when an event occurs.
        /// </summary>
        public event EventHandler<UpdateEventArgs> Event;

        /// <summary>
        /// Called when an event occurs.
        /// </summary>
        /// <param name="message">The message.</param>
        private bool OnEvent(string message)
        {
            if (Event != null)
            {
                var eventArg = new UpdateEventArgs(message);
                Event(null, eventArg);

                return eventArg.ShouldUpdate;
            }
            return false;
        }

        #endregion


        #region Methods

        /// <summary>
        /// Starts the monitoring.
        /// </summary>
        public void StartMonitoring()
        {
            try
            {
                Log.Write("{0} started. Monitoring every {1}s.", MethodInfoHelper.GetCurrentMethodName(), _localConfig.CheckInterval);

                if (_localConfig != null)
                    _timer = new Timer(Check, null, 5000, _localConfig.CheckInterval * 1000);
            }
            catch (Exception ex)
            {
                Log.Write("{0} failed. {1}", MethodInfoHelper.GetCurrentMethodName(), ex.Message);
            }
            finally
            {
                Log.Write("{0} ended.", MethodInfoHelper.GetCurrentMethodName());
            }
        }

        /// <summary>
        /// Stops the monitoring.
        /// </summary>
        public void StopMonitoring()
        {
            try
            {
                Log.Write("{0} started.", MethodInfoHelper.GetCurrentMethodName());
                if (_timer == null)
                {
                    Log.Write("Monitoring was already stopped.");
                    return;
                }
                _timer.Dispose();
            }
            catch (Exception ex)
            {
                Log.Write("{0} failed. {1}", MethodInfoHelper.GetCurrentMethodName(), ex.Message);
            }
            finally
            {
                Log.Write("{0} ended.", MethodInfoHelper.GetCurrentMethodName());
            }

        }

        /// <summary>
        /// Checks the specified state.
        /// </summary>
        /// <param name="state">The state.</param>
        private void Check(object state)
        {
            try
            {
                Log.Write("{0} started.", MethodInfoHelper.GetCurrentMethodName());

                if (_updating)
                {
                    Log.Write("Updater is already updating.");
                }

                var fetch = new Fetch(2, 5000, 500);
                var remoteUri = new Uri(_localConfig.RemoteConfigUri);
                fetch.Load(remoteUri.AbsoluteUri);

                if (!fetch.Success)
                {
                    Log.Write("Fetch error: {0}", fetch.Response.StatusDescription);
                    _remoteConfig = null;
                    return;
                }

                string data = Encoding.UTF8.GetString(fetch.ResponseData);
                _remoteConfig = new Manifest(data);

                if (_remoteConfig == null)
                    return;

                if (_localConfig.SecurityToken != _remoteConfig.SecurityToken)
                {
                    Log.Write("Security token mismatch.");
                    return;
                }

                Log.Write("Remote config is valid. Local version is {0}. Remote version is {1}.",
                    _localConfig.Version, _remoteConfig.Version);

                if (_remoteConfig.Version == _localConfig.Version)
                {
                    Log.Write("Versions are the same.");
                    return;
                }

                if (_remoteConfig.Version < _localConfig.Version)
                {
                    Log.Write("Remote version is older.");
                    return;
                }

                if (OnEvent(string.Format("Current version is {0}. Do you want to ugrade to version {1}?",
                    _localConfig.Version, _remoteConfig.Version)))
                {
                    _updating = true;
                    Update();
                    _updating = false;
                }
            }
            catch (Exception ex)
            {
                Log.Write("{0} failed. {1}", MethodInfoHelper.GetCurrentMethodName(), ex.Message);
            }
            finally
            {
                Log.Write("{0} ended.", MethodInfoHelper.GetCurrentMethodName());
                _updating = false;
            }
        }

        /// <summary>
        /// Updates this instance.
        /// </summary>
        private void Update()
        {
            try
            {
                Log.Write("{0} started.", MethodInfoHelper.GetCurrentMethodName());
                string upgradeFolderPath = Path.Combine(Path.GetTempPath(), UpgradeFolderName);

                DeleteUpgradeFolder(upgradeFolderPath);
                Directory.CreateDirectory(upgradeFolderPath);

                // Download file in manifest.
                Log.Write("Fetching '{0}'.", _remoteConfig.Payload);

                var url = _remoteConfig.BaseUri + _remoteConfig.Payload;
                var file = Fetch.Get(url);
                if (file == null)
                {
                    Log.Write("Fetch failed.");
                    return;
                }

                var zipFilePath = Path.Combine(upgradeFolderPath, _remoteConfig.Payload);

                var infoZipFilePath = new FileInfo(zipFilePath);
                Directory.CreateDirectory(infoZipFilePath.DirectoryName);

                File.WriteAllBytes(zipFilePath, file);

                Unzip(infoZipFilePath.DirectoryName, zipFilePath);

                StartUgradeProcess(infoZipFilePath.DirectoryName);
                StopApplication();
            }
            catch (Exception ex)
            {
                Log.Write("{0} failed. {1}", MethodInfoHelper.GetCurrentMethodName(), ex.Message);
                throw ex;
            }
            finally
            {
                Log.Write("{0} ended.", MethodInfoHelper.GetCurrentMethodName());
            }
        }

        private void StartUgradeProcess(string zipFolderPath)
        {
            string setupFilePath = Path.Combine(zipFolderPath + "\\" + SetupFileName);
            if (IsAdministrator() == false)
            {
                ProcessStartInfo infoSetup = new ProcessStartInfo(setupFilePath);
                infoSetup.Verb = "runas";
                Process.Start(infoSetup);
            }
            else
            {
                Process.Start(setupFilePath);
            }
        }

        private void Unzip(string zipFolderPath, string zipfilePath)
        {
            if (Regex.IsMatch(_remoteConfig.Payload, @"\.zip"))
            {
                try
                {
                    using (ZipArchive archive = ZipFile.Open(zipfilePath, ZipArchiveMode.Read))
                    {
                        archive.ExtractToDirectory(zipFolderPath);
                    }

                    File.Delete(zipfilePath);
                }
                catch (Exception ex)
                {
                    Log.Write("{0} failed. {1}", MethodInfoHelper.GetCurrentMethodName(), ex.Message);
                    throw ex;
                }
            }
        }

        private void DeleteUpgradeFolder(string upgradeFolderPath)
        {
            // Clean up failed attempts.
            if (Directory.Exists(upgradeFolderPath))
            {
                Log.Write("WARNING: Work directory already exists.");
                try
                {
                    Directory.Delete(upgradeFolderPath, true);
                }
                catch (IOException ex)
                {
                    Log.Write("{0} failed. Cannot delete open directory {1} - Exception {2}",
                        MethodInfoHelper.GetCurrentMethodName(), upgradeFolderPath, ex.Message);
                    throw ex;
                }
                catch (Exception ex)
                {
                    Log.Write("{0} failed. {1}", MethodInfoHelper.GetCurrentMethodName(), ex.Message);
                    throw ex;
                }
            }
        }

        private bool IsAdministrator()
        {
            WindowsIdentity identity = WindowsIdentity.GetCurrent();
            WindowsPrincipal principal = new WindowsPrincipal(identity);
            return principal.IsInRole(WindowsBuiltInRole.Administrator);
        }


        private void StopApplication()
        {
            try
            {
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
                }
            }
            catch (Exception ex)
            {
                Log.Write("{0} failed. {1}", MethodInfoHelper.GetCurrentMethodName(), ex.Message);
            }
        }

        #endregion
    }
}
