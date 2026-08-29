"use client";

export async function exportExcel(fileName: string, rows: Record<string, string | number>[], sheetName = "ECO Healthy") {
  const XLSX = await import("xlsx");
  const sheet = XLSX.utils.json_to_sheet(rows);
  sheet["!cols"] = Object.keys(rows[0] ?? {}).map((key) => ({ wch: Math.max(14, key.length + 4) }));
  const book = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(book, sheet, sheetName.slice(0, 31));
  XLSX.writeFile(book, fileName.endsWith(".xlsx") ? fileName : `${fileName}.xlsx`);
}

export async function downloadElementPdf(elementId: string, fileName: string) {
  const element = document.getElementById(elementId);
  if (!element) throw new Error("Document element was not found");
  const [{ default: html2canvas }, { jsPDF }] = await Promise.all([import("html2canvas"), import("jspdf")]);
  const canvas = await html2canvas(element, { scale: 2, backgroundColor: "#ffffff", useCORS: true });
  const pdf = new jsPDF({ orientation: "portrait", unit: "mm", format: "a4", compress: true });
  const width = 190;
  const height = (canvas.height * width) / canvas.width;
  const image = canvas.toDataURL("image/jpeg", 0.94);
  if (height <= 277) pdf.addImage(image, "JPEG", 10, 10, width, height);
  else {
    let offset = 0;
    while (offset < height) {
      if (offset > 0) pdf.addPage();
      pdf.addImage(image, "JPEG", 10, 10 - offset, width, height);
      offset += 277;
    }
  }
  pdf.save(fileName.endsWith(".pdf") ? fileName : `${fileName}.pdf`);
}

export function money(value: number) {
  return `${value.toLocaleString("ar-EG", { maximumFractionDigits: 2 })} ج`;
}
