using System;
using System.IO;

namespace Quote.Update
{
    public static class Log
    {
        #region Initialization

        static Log ()
        {
            LogType = ELogType.TxtFile;
            Prefix = "[Update] ";

            try
            {
                var logFileInfo = new FileInfo(Path.Combine(Path.GetTempPath(), "QuoteUpgradeLog\\UpdateLog.txt"));

                if (!Directory.Exists(logFileInfo.DirectoryName))
                    Directory.CreateDirectory(logFileInfo.DirectoryName);

                if (!File.Exists(logFileInfo.FullName))
                    File.Create(logFileInfo.FullName);

                Filepath = logFileInfo.FullName;
            }
            catch(Exception)
            {
                //ignore
            }

            
        }

        #endregion


        #region Fields & Properties

        /// <summary>
        /// Gets or sets a value indicating whether this <see cref="Log"/> logs to.
        /// </summary>
        public static ELogType LogType { get; set; }

        /// <summary>
        /// Gets or sets the prefix.
        /// </summary>
        /// <value>The prefix.</value>
        public static string Prefix { get; set; }

        public static string Filepath;

        #endregion


        #region Events

        /// <summary>
        /// Occurs when an event occurs.
        /// </summary>
        public static event EventHandler<LogEventArgs> Event;

        /// <summary>
        /// Called when an event occurs.
        /// </summary>
        /// <param name="message">The message.</param>
        private static void OnEvent (string message)
        {
            if(Event != null)
                Event(null, new LogEventArgs(message));
        }

        #endregion


        #region Methods

        /// <summary>
        /// Writes to the log.
        /// </summary>
        /// <param name="format">The format.</param>
        /// <param name="args">The arguments.</param>
        public static void Write (string format, params object[] args)
        {
            Write(ELogLevel.Debug, format, args);
        }

        /// <summary>
        /// Writes to the log.
        /// </summary>
        /// <param name="ELogLevel">Log Level</param>
        /// <param name="format">The format.</param>
        /// <param name="args">The arguments.</param>
        public static void Write(ELogLevel logLevel, string format, params object[] args)
        {
            string message = string.Format(format, args);

            if (logLevel == ELogLevel.Fatal)
                OnEvent(message);

            switch (LogType)
            {
                case ELogType.TxtFile:
                    Writer writer = new Writer(Filepath);
                    message = DateTime.Now.ToString("yyyy-MM-dd_hh-mm-ss") + " - Level: " + logLevel.ToString() + " - " + message;
                    writer.WriteToFile(message);
                    break;
                case ELogType.Console:
                    System.Console.WriteLine(message);
                    break;
                case ELogType.Debug:
                    System.Diagnostics.Debug.WriteLine(message);
                    break;
                default:
                    System.Diagnostics.Debug.WriteLine(message);
                    break;
            }
        }

        #endregion
    }

    public enum ELogType
    {
        Console = 10,
        Debug = 20,
        TxtFile = 30
    }

    public enum ELogLevel
    {
        Debug = 1,
        Info = 2,
        Error = 3,
        Fatal = 4
    }
}
