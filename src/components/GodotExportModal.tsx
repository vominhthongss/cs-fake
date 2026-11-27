import React, { useState } from 'react';
import { Check, Copy, Download, FileCode2, X } from 'lucide-react';
import { GODOT_SCRIPTS } from '../game/godotScripts';

interface GodotExportModalProps {
  onClose: () => void;
}

export const GodotExportModal: React.FC<GodotExportModalProps> = ({ onClose }) => {
  const [selectedIdx, setSelectedIdx] = useState(0);
  const [copied, setCopied] = useState(false);

  const activeFile = GODOT_SCRIPTS[selectedIdx];

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(activeFile.code);
      setCopied(true);
      setTimeout(() => setCopied(false), 1600);
    } catch {
      // Clipboard fallback ignored
    }
  };

  const handleDownload = (filename: string, content: string) => {
    const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  return (
    <div
      className="fixed inset-0 z-40 flex items-center justify-center p-4"
      style={{ backgroundColor: 'rgba(10, 9, 8, 0.86)' }}
    >
      <div
        className="w-full max-w-5xl h-[85vh] rounded-lg border border-amber-500/40 flex flex-col overflow-hidden shadow-2xl"
        style={{ backgroundColor: 'rgba(20, 18, 15, 0.98)' }}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-3.5 border-b border-stone-800">
          <div>
            <h2 className="text-lg font-black uppercase tracking-wide text-stone-100">
              Godot 4.3+ GDScript Source Architecture
            </h2>
            <p className="text-xs font-mono text-stone-400">
              Weapons, CS Counter-Strafe Physics, Grenade RigidBody3D & Utility Bot AI
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close Godot GDScript Viewer"
            className="p-1.5 rounded border border-stone-700 text-stone-300 hover:bg-stone-800 cursor-pointer"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 flex flex-col md:flex-row min-h-0">
          {/* File Sidebar */}
          <div className="w-full md:w-64 border-b md:border-b-0 md:border-r border-stone-800 p-3 space-y-1.5 overflow-y-auto bg-stone-950/60">
            {GODOT_SCRIPTS.map((file, idx) => (
              <button
                key={file.filename}
                type="button"
                onClick={() => setSelectedIdx(idx)}
                className={`w-full text-left px-3 py-2 rounded border transition-colors cursor-pointer ${
                  selectedIdx === idx
                    ? 'bg-amber-600/20 border-amber-500/70 text-amber-200'
                    : 'bg-stone-900/70 border-stone-800 text-stone-300 hover:border-stone-700'
                }`}
              >
                <div className="flex items-center gap-2 font-mono text-xs font-bold">
                  <FileCode2 className="w-3.5 h-3.5 text-amber-400 shrink-0" />
                  <span className="truncate">{file.filename}</span>
                </div>
                <div className="text-[10px] font-mono text-stone-400 mt-0.5 line-clamp-2">
                  {file.role}
                </div>
              </button>
            ))}
          </div>

          {/* Code Viewer */}
          <div className="flex-1 flex flex-col min-w-0 min-h-0">
            <div className="flex items-center justify-between px-4 py-2.5 border-b border-stone-800 bg-stone-900/50">
              <div className="text-xs font-mono text-amber-300 truncate">{activeFile.path}</div>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={handleCopy}
                  className="flex items-center gap-1.5 px-3 py-1 rounded border border-stone-700 bg-stone-900 hover:bg-stone-800 text-xs font-mono text-stone-200 cursor-pointer"
                >
                  {copied ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                  {copied ? 'Copied' : 'Copy'}
                </button>
                <button
                  type="button"
                  onClick={() => handleDownload(activeFile.filename, activeFile.code)}
                  className="flex items-center gap-1.5 px-3 py-1 rounded bg-amber-600 hover:bg-amber-500 text-stone-950 text-xs font-mono font-bold cursor-pointer"
                >
                  <Download className="w-3.5 h-3.5" />
                  Download .gd
                </button>
              </div>
            </div>

            <pre className="flex-1 p-4 overflow-auto text-xs font-mono leading-relaxed text-stone-200 bg-stone-950">
              <code>{activeFile.code}</code>
            </pre>
          </div>
        </div>
      </div>
    </div>
  );
};
