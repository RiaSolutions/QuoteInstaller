using System;
using System.IO;
using System.Net;
using System.Text;
using System.Threading;

namespace Quote.Update
{
    /// <summary>
    /// Fetches web pages.
    /// </summary>
    public class Fetch
    {
        #region Constructor

         public Fetch()
        {
            _retries = 2;
            _timeout = 5000;
            _retrySleep = 500;
        }

        public Fetch(int retries, int timeout, int retrySleep)
        {
            _retries = retries;
            _timeout = timeout;
            _retrySleep = retrySleep;
        }

        #endregion


        #region Properties & Fields

        private int _retries;
        private int _timeout;
        private int _retrySleep;

        /// <summary>
        /// Gets the response.
        /// </summary>
        public HttpWebResponse Response{ get; private set; }

        /// <summary>
        /// Gets the response data.
        /// </summary>
        public byte[] ResponseData { get; private set; }

        /// <summary>
        /// Gets a value indicating whether this <see cref="Fetch"/> is success.
        /// </summary>
        /// <value><c>true</c> if success; otherwise, <c>false</c>.</value>
        public bool Success { get; private set; }

        #endregion


        #region Methods

        /// <summary>
        /// Gets the specified URL.
        /// </summary>
        /// <param name="url">The URL.</param>
        /// <returns></returns>
        public void Load(string url)
        {
            for (int retry = 0; retry < _retries; retry++)
            {
                try
                {
                    Log.Write("{0} started for url = {1} and retry = {2}", MethodInfoHelper.GetCurrentMethodName(), url, retry);

                    var req = HttpWebRequest.Create(url) as HttpWebRequest;
                    req.Timeout = _timeout;

                    Response = req.GetResponse() as HttpWebResponse;
                    switch (Response.StatusCode)
                    {
                        case HttpStatusCode.Found:
                            // This is a redirect to an error page, so ignore.
                            Log.Write("Found (302), ignoring ");
                            break;
                        case HttpStatusCode.OK:
                            // This is a valid page.
                            using (var sr = Response.GetResponseStream())
                            {
                                using (var ms = new MemoryStream())
                                {
                                    for (int b; (b = sr.ReadByte()) != -1; )
                                        ms.WriteByte((byte)b);

                                    ResponseData = ms.ToArray();
                                }
                            }
                            break;
                        default:
                            // This is unexpected.
                            Log.Write(Response.StatusCode.ToString());
                            break;
                    }
                    Success = true;
                    break;
                }
                catch (WebException ex)
                {
                    Log.Write("{0} failed. {1}", MethodInfoHelper.GetCurrentMethodName(), ex.Message);

                    Response = ex.Response as HttpWebResponse;
                    if (ex.Status == WebExceptionStatus.Timeout)
                    {
                        Thread.Sleep(_retrySleep);
                        continue;
                    }
                    break;
                }
                finally
                {
                    Log.Write("{0} ended.", MethodInfoHelper.GetCurrentMethodName());
                }
            }
        }

        /// <summary>
        /// Gets the string.
        /// </summary>
        /// <returns></returns>
        public string GetString()
        {
            var encoder = string.IsNullOrEmpty(Response.ContentEncoding) ?
                Encoding.UTF8 : Encoding.GetEncoding(Response.ContentEncoding);

            if (ResponseData == null)
                return string.Empty;

            return encoder.GetString(ResponseData);
        }

        /// <summary>
        /// Gets the specified URL.
        /// </summary>
        /// <param name="url">The URL.</param>
        /// <returns></returns>
        public static byte[] Get(string url)
        {
            var f = new Fetch();
            f.Load(url);
            return f.ResponseData;
        }

        #endregion
    }
}
