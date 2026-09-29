import './FileUpload.css';
// Encapsula o input nativo de arquivo e estiliza ::file-selector-button com tokens.
export function FileUpload(props: { onChange: (f: File | null) => void; label: string }) {
  return (
    <label className="ds-file-upload">
      {props.label}
      <input type="file" onChange={(e) => props.onChange(e.target.files?.[0] ?? null)} />
    </label>
  );
}
