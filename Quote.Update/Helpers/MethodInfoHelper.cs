using System;
using System.Diagnostics;
using System.Reflection;
using System.Runtime.CompilerServices;

namespace Quote.Update
{
    internal class MethodInfoHelper
    {
        [MethodImpl(MethodImplOptions.NoInlining)]
        public static string GetCurrentMethodName()
        {
            try
            {
                var stackTrace = new StackTrace();
                MethodBase method = stackTrace.GetFrame(1).GetMethod();
                string methodName = method.Name;

                if (method.ReflectedType == null)
                    return methodName;

                string className = method.ReflectedType.Name;
                return className + "." + methodName;
            }
            catch
            {
                // ignored
            }
            return "";
        }
    }
}
