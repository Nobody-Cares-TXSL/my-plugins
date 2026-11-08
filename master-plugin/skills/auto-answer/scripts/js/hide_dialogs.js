(() => {
  const AA = window.__aa;
  const ROOT = AA.pickRoot().doc;
  const dialogs = ROOT.querySelectorAll('[role=dialog]');
  dialogs.forEach(d => { d.style.display = 'none'; });
  return JSON.stringify({ hidden: dialogs.length });
})()
