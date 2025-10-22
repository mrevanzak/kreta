//
//  AddTrain.swift
//  tututut
//
//  Created by Gilang Banyu Biru Erassunu on 21/10/25.
//

import SwiftUI

// MARK: - Model

struct TrainMock: Identifiable {
    let id = UUID()
    let number: String
    let name: String
    let from: String
    let to: String
    let city: String
}

let sampleTrains: [TrainMock] = [
    .init(number: "298", name: "Probowangi", from: "KTG", to: "SGU", city: "Bandung"),
    .init(number: "293", name: "TawangAlun", from: "BG", to: "KTG", city: "Bandung"),
    .init(number: "2",   name: "Argo Bromo Anggrek", from: "GBR", to: "SBI", city: "Bandung"),
    .init(number: "71",  name: "Mutiara Selatan", from: "SGU", to: "BD", city: "Bandung"),
    .init(number: "86",  name: "Sancaka", from: "SGU", to: "BD", city: "Bandung"),
    .init(number: "9",   name: "Argo Wilis", from: "SGU", to: "BD", city: "Bandung"),
]


struct AddTrain: View {
    @State private var query: String = ""
    let trains: [TrainMock] = sampleTrains
    var onSelect: (TrainMock) -> Void
    
    var filtered: [TrainMock] {
        guard !query.isEmpty else { return trains }
        return trains.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.number.localizedCaseInsensitiveContains(query) ||
            $0.from.localizedCaseInsensitiveContains(query) ||
            $0.to.localizedCaseInsensitiveContains(query)
        }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Tambah Perjalanan Kereta")
                        .font(.title2).bold()
                    Text("Pilih Stasiun Keberangkatan")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)
            
            // Search bar with clear button
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    TextField("Cari Nama Kereta", text: $query)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(.ultraThinMaterial, in: Capsule())

                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 2)
                }
            }
            .padding(.horizontal)

            // List
            List {
                ForEach(filtered) { train in
                    Button {
                        onSelect(train)
                    } label: {
                        TrainRow(train: train)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
        }
        .padding(.top, 8)
        .padding(.horizontal, 30)
    }
}

// MARK: - Sheet

struct TrainPickerSheet: View {
    let trains: [TrainMock]
    var onSelect: (TrainMock) -> Void

    @State private var query: String = ""

    var filtered: [TrainMock] {
        guard !query.isEmpty else { return trains }
        return trains.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.number.localizedCaseInsensitiveContains(query) ||
            $0.from.localizedCaseInsensitiveContains(query) ||
            $0.to.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Title
            HStack {
                Text("Tambah Perjalanan Kereta")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)

            // Search bar with clear button
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    TextField("Cari Nama Kota", text: $query)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(.ultraThinMaterial, in: Capsule())

                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 2)
                }
            }
            .padding(.horizontal)

            // List
            List {
                ForEach(filtered) { train in
                    Button {
                        onSelect(train)
                    } label: {
                        TrainRow(train: train)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
        }
        .padding(.top, 8)
    }
}

// MARK: - Row

struct TrainRow: View {
    let train: TrainMock

    var body: some View {
        HStack(spacing: 14) {
            // Green circle with number
            ZStack {
                Circle()
                    .fill(Color(.systemGreen))
                    .frame(width: 43, height: 43)
                Text(train.from)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(train.name)
                    .font(.title3).fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text(train.city)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }
}
#Preview {
    AddTrain { TrainMock in
        
    }
}
