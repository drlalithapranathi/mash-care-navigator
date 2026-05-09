export default function LoadingSpinner() {
  return (
    <div className="min-h-screen bg-slate-50 flex items-center justify-center">
      <div className="text-center">
        <div className="inline-block w-12 h-12 border-4 border-blue-200 border-t-blue-700 rounded-full animate-spin mb-4" />
        <h2 className="text-lg font-semibold text-slate-700">MASH Care Navigator</h2>
        <p className="text-slate-500 text-sm mt-1">Loading patient data…</p>
      </div>
    </div>
  );
}
