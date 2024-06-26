//
//  CurriculumPreview.swift
//  Life@USTC (iOS)
//
//  Created by TiankaiMa on 2023/1/5.
//

import SwiftUI

struct LectureView: View {
    var lecture: Lecture
    var color: Color = .red

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill((lecture.course?.color() ?? color).opacity(0.8))
                .frame(width: 5, height: 50)

            ZStack {
                RoundedCornersShape(corners: [.topRight, .bottomRight], radius: 5)
                    .fill((lecture.course?.color() ?? color).opacity(0.05))
                    .frame(height: 50)

                HStack {
                    VStack(alignment: .leading) {
                        Text(lecture.name)
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("\(lecture.teacherName) @ **\(lecture.location)**")
                            .font(.footnote)
                            .foregroundColor(.gray.opacity(0.8))
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text(lecture.startDate.stripHMwithTimezone())
                            .font(.subheadline)
                            .fontWeight(.heavy)
                            .foregroundColor(.mint)
                        Text(lecture.endDate.stripHMwithTimezone())
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.8))
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        .if(lecture.endDate < Date()) {
            $0
                .strikethrough()
                .grayscale(1.0)
        }
        .if(lecture != Lecture.example) {
            $0.lectureSheet(lecture: lecture)
        }
    }
}

struct CurriculumTodayView: View {
    var lectureListA: [Lecture] = []
    var lectureListB: [Lecture] = []
    var listAText: String? = "Today"
    var listBText: String? = "Tomorrow"

    @ViewBuilder
    var noLectureView: some View {
        ZStack {
            LectureView(lecture: .example)
                .redacted(reason: .placeholder)

            VStack {
                Text("Nothing here")
                    .lineLimit(1)
                    .font(.system(.body, weight: .semibold))

                Text("Enjoy!")
                    .lineLimit(1)
                    .font(.caption)
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }

    @ViewBuilder
    func makeView(
        with lectures: [Lecture],
        text: String? = nil,
        color: Color = Color.accentColor
    ) -> some View {
        VStack(alignment: .leading) {
            if let text {
                Text(text.localized)
                    .foregroundColor(.gray)
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
            }

            ForEach(lectures) { lecture in
                LectureView(lecture: lecture, color: color)
            }

            if lectures.isEmpty {
                noLectureView
            }

            Spacer()
        }
    }

    var body: some View {
        VStack {
            makeView(with: lectureListA, text: listAText, color: .mint)

            Spacer()
                .frame(height: 20)

            makeView(with: lectureListB, text: listBText, color: .orange)
        }
    }
}

#Preview {
    NavigationStack {
        VStack {
            CurriculumTodayView(
                lectureListA: [.example, .example],
                lectureListB: [.example]
            )
            .card()

            CurriculumTodayView(
                lectureListA: [.example, .example],
                lectureListB: []
            )
            .card()
        }
    }
}

extension CurriculumTodayView {
    @ViewBuilder
    var titleView: some View {
        Text("Class")
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(.mint)
            )
    }

    @ViewBuilder
    func makeListWidget(
        with lectures_: [Lecture],
        color: Color = Color.accentColor,
        numberToShow: Int = 2
    ) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                titleView
                Spacer()
                
                Text(String(format: "Total: %@ lectures".localized, String(lectures_.count)))
                    .font(.system(.caption, design: .monospaced, weight: .light))
            }
            .padding(.bottom, 10)

            let lectures = lectures_.isEmpty ? Array(repeating: .example, count: 6) : lectures_

            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lectures.prefix(numberToShow).enumerated()), id: \.1.id) { index, lecture in
                        LectureView(lecture: lecture, color: color)
                    }
                }.if(lectures_.isEmpty) {
                    $0
                        .redacted(reason: .placeholder)
                        .blur(radius: 5)
                }

                if lectures_.isEmpty {
                    Text("No courses today!")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            if numberToShow > 2 {
                Spacer()
            }
        }
    }
}

#Preview {
    NavigationStack {
        VStack {
            CurriculumTodayView()
                .makeListWidget(
                    with: [],
                    color: .mint
                )
                .card()

            CurriculumTodayView()
                .makeListWidget(
                    with: [.example, .example, .example],
                    color: .mint
                )
                .card()

            CurriculumTodayView()
                .makeListWidget(
                    with: [.example, .example, .example, .example, .example, .example, .example],
                    color: .mint
                )
                .card()

            CurriculumTodayView()
                .makeListWidget(
                    with: [.example, .example, .example, .example, .example, .example, .example],
                    color: .mint,
                    numberToShow: 5
                )
                .card()
        }
    }
}

extension CurriculumTodayView {
    @ViewBuilder
    func makeWidget(
        with lecture_: Lecture?
    ) -> some View {
        let lecture = lecture_ ?? .example

        ZStack {
            VStack(alignment: .leading) {
                HStack {
                    titleView

                    Text(lecture.location)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .foregroundColor(.mint)
                }
                Text(lecture.name)
                    .lineLimit(2)
                    .fontWeight(.bold)

                Spacer()

                Text(lecture.startDate.stripHMwithTimezone())
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.mint)
                HStack {
                    Text(lecture.endDate.stripHMwithTimezone())
                    Spacer()
                    Text(lecture.teacherName)
                }
                .font(.subheadline)
                .fontWeight(.regular)
                .foregroundColor(.gray.opacity(0.8))
            }
            .if(lecture_ == nil) {
                $0
                    .redacted(reason: .placeholder)
                    .blur(radius: 5)
            }

            if lecture_ == nil {
                VStack(alignment: .center, spacing: 20) {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 50))
                        .fontWeight(.regular)
                        .frame(width: 60, height: 60)
                        .padding(5)
                        .fontWeight(.heavy)
                        .foregroundColor(.mint.opacity(0.8))
                    Text("No courses today!")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        VStack {
            CurriculumTodayView().makeWidget(with: nil)
                .frame(width: 200, height: 200)
                .border(.blue)
                .card()

            CurriculumTodayView().makeWidget(with: .example)
                .frame(width: 200, height: 200)
                .border(.blue)
                .card()
        }
    }
}
