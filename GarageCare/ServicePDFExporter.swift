import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PDFDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum ServicePDFExporter {
    static func makePDF(vehicles: [Vehicle], records: [ServiceRecord]) -> Data {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let names = Dictionary(uniqueKeysWithValues: vehicles.map { ($0.id, $0.displayName) })
        return renderer.pdfData { context in
            var y: CGFloat = 0
            func nextPage() {
                context.beginPage()
                y = 40
            }
            func line(_ text: String, bold: Bool = false, height: CGFloat = 22) {
                if y + height > page.height - 42 { nextPage() }
                let font = bold ? UIFont.boldSystemFont(ofSize: 13) : UIFont.systemFont(ofSize: 11)
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byTruncatingTail
                (text as NSString).draw(in: CGRect(x: 42, y: y, width: 510, height: height),
                                        withAttributes: [.font: font, .foregroundColor: UIColor.black,
                                                         .paragraphStyle: paragraph])
                y += height
            }
            nextPage()
            line("Мой гараж — история обслуживания", bold: true, height: 28)
            line("Экспорт: " + Formatters.russianDate(.now))
            y += 12
            for record in records.sorted(by: { $0.date > $1.date }) {
                if y + 110 > page.height - 42 { nextPage() }
                line((names[record.vehicleID] ?? "Автомобиль") + " · " + record.title, bold: true)
                line(Formatters.russianDate(record.date) + " · " + Formatters.mileage(record.mileage))
                line("Стоимость: " + String(format: "%.2f", record.cost) + " " + record.currency)
                if !record.parts.isEmpty { line("Запчасти: " + record.parts) }
                if !record.notes.isEmpty { line("Заметка: " + record.notes) }
                if let data = record.receiptImageData,
                   let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 {
                    let maxW: CGFloat = 260
                    let maxH: CGFloat = 230
                    let scale = min(maxW / image.size.width, maxH / image.size.height)
                    let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    if y + size.height > page.height - 42 { nextPage() }
                    image.draw(in: CGRect(x: 42, y: y, width: size.width, height: size.height))
                    y += size.height + 8
                }
                y += 12
            }
        }
    }
}
