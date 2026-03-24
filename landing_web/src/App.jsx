import React, { useState } from "react";

const APK_DOWNLOAD_URL = "https://drive.google.com/";

const painPoints = [
  {
    icon: "⏳",
    title: "Mất nhiều thời gian nghĩ món",
    text: "Không còn mất 30 phút chỉ để trả lời câu hỏi: hôm nay ăn gì?"
  },
  {
    icon: "🥦",
    title: "Có nguyên liệu nhưng bí ý tưởng",
    text: "Ứng dụng gợi ý món theo đúng những gì đang có trong tủ lạnh của bạn."
  },
  {
    icon: "🔥",
    title: "Ngại công thức rối rắm",
    text: "Mỗi bước nấu được trình bày rõ ràng, ngắn gọn, ai cũng làm theo được."
  }
];

const steps = [
  {
    id: "01",
    title: "Chọn nguyên liệu sẵn có",
    text: "Nhập nhanh các nguyên liệu bạn đang có như trứng, cà chua, đậu hũ, thịt..."
  },
  {
    id: "02",
    title: "Nhận gợi ý món phù hợp",
    text: "Bếp Trợ Lý đề xuất danh sách món hợp vị, kèm thời gian nấu dự kiến."
  },
  {
    id: "03",
    title: "Nấu theo hướng dẫn",
    text: "Xem công thức từng bước và hoàn thành bữa ăn đúng giờ, ít áp lực hơn."
  }
];

const features = [
  {
    title: "Gợi ý món theo nguyên liệu",
    text: "Biến những nguyên liệu sẵn có thành bữa ăn ngon, giảm lãng phí mỗi ngày."
  },
  {
    title: "Công thức dễ hiểu, dễ làm",
    text: "Ngôn ngữ thân thiện, phù hợp cả người mới vào bếp lần đầu."
  },
  {
    title: "Ước tính thời gian nấu rõ ràng",
    text: "Chủ động sắp xếp lịch bận mà vẫn có bữa ăn chỉn chu cho bản thân và gia đình."
  }
];

const faqs = [
  {
    q: "Bếp Trợ Lý có miễn phí không?",
    a: "Có. Bạn có thể tải và dùng miễn phí các tính năng cốt lõi ngay từ lần đầu."
  },
  {
    q: "Ứng dụng có phù hợp cho người mới nấu không?",
    a: "Rất phù hợp. Công thức được chia từng bước ngắn, rõ ràng và dễ theo dõi."
  },
  {
    q: "Tôi có thể dùng khi chỉ có ít nguyên liệu không?",
    a: "Có. Bếp Trợ Lý vẫn gợi ý được món phù hợp ngay cả khi tủ lạnh còn rất ít đồ."
  }
];

function App() {
  const [openFaq, setOpenFaq] = useState(0);

  return (
    <div className="page">
      <header className="topbar container">
        <div className="brand">Bếp Trợ Lý</div>
        <nav className="nav">
          <a href="#tinh-nang">Tính năng</a>
          <a href="#cach-hoat-dong">Cách hoạt động</a>
          <a href="#danh-gia">Đánh giá</a>
        </nav>
      </header>

      <main>
        <section className="hero container">
          <div className="hero-copy">
            <span className="badge">Trợ lý ảo cho gian bếp Việt</span>
            <h1>
              Mở tủ lạnh,
              <br />
              có ngay món hợp vị
              <br />
              cho bữa tối hôm nay
            </h1>
            <p>
              Không cần đau đầu nghĩ thực đơn. Bếp Trợ Lý gợi ý món theo nguyên
              liệu bạn đang có, kèm công thức từng bước và thời gian nấu rõ ràng.
            </p>
            <div className="cta-row">
              <a
                className="btn btn-primary"
                href={APK_DOWNLOAD_URL}
                target="_blank"
                rel="noreferrer"
              >
                Tải file APK
              </a>
              <a className="btn btn-secondary" href="#huong-dan-cai-apk">
                Cách cài APK
              </a>
            </div>
            <small>
              Tải trực tiếp từ Google Drive • 10.000+ bữa ăn đã được gợi ý
            </small>
          </div>
          <div className="hero-visual" aria-hidden="true">
            <div className="phone phone-back" />
            <div className="phone phone-front">
              <div className="phone-content">
                <h4>Hôm nay nấu gì?</h4>
                <p>Bạn đang có 5 nguyên liệu trong tủ lạnh.</p>
              </div>
            </div>
          </div>
        </section>

        <section className="section container">
          <h2>Bạn đang mất nhiều thời gian cho việc nghĩ món</h2>
          <p className="section-sub">
            Từ cảm giác bối rối đến bữa ăn gọn gàng: Bếp Trợ Lý giúp bạn đi từ
            câu hỏi đến hành động chỉ trong vài phút.
          </p>
          <div className="grid-3">
            {painPoints.map((item) => (
              <article key={item.title} className="card">
                <span className="emoji">{item.icon}</span>
                <h3>{item.title}</h3>
                <p>{item.text}</p>
              </article>
            ))}
          </div>
        </section>

        <section id="cach-hoat-dong" className="section section-tinted">
          <div className="container">
            <span className="section-tag">Cách hoạt động</span>
            <h2>3 bước từ tủ lạnh đến bữa tối gọn nhẹ</h2>
            <div className="grid-3">
              {steps.map((step) => (
                <article key={step.id} className="card step-card">
                  <strong>{step.id}</strong>
                  <h3>{step.title}</h3>
                  <p>{step.text}</p>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section id="tinh-nang" className="section container feature-layout">
          <div>
            <span className="section-tag">Tính năng nổi bật</span>
            <h2>Một trợ lý bếp cá nhân hóa cho mỗi ngày</h2>
            <div className="stack">
              {features.map((feature) => (
                <article key={feature.title} className="card compact">
                  <h3>{feature.title}</h3>
                  <p>{feature.text}</p>
                </article>
              ))}
            </div>
          </div>
          <div className="mockup-box">Screenshot ứng dụng đặt tại đây</div>
        </section>

        <section id="danh-gia" className="section social-proof">
          <div className="container">
            <h2>Được yêu thích bởi cộng đồng nấu ăn bận rộn</h2>
            <div className="stats">
              <article>
                <strong>10.000+</strong>
                <span>Bữa ăn đã được gợi ý</span>
              </article>
              <article>
                <strong>4.8/5</strong>
                <span>Điểm đánh giá trung bình</span>
              </article>
              <article>
                <strong>18 phút</strong>
                <span>Thời gian nấu trung bình</span>
              </article>
            </div>
            <blockquote>
              “Trước đây mình tốn rất nhiều thời gian để nghĩ món. Từ khi dùng
              Bếp Trợ Lý, mình chốt món nhanh hơn, nấu nhàn hơn và đỡ lãng phí
              đồ ăn trong tủ lạnh.”
              <cite>Lan Anh • Nhân viên văn phòng, Q.3</cite>
            </blockquote>
          </div>
        </section>

        <section className="section container faq-section">
          <h2 id="huong-dan-cai-apk">Hướng dẫn cài APK nhanh</h2>
          <div className="apk-guide card">
            <p>
              1) Nhấn nút <strong>Tải file APK</strong> để mở Google Drive.
            </p>
            <p>
              2) Tải file về máy Android, sau đó mở file để cài đặt.
            </p>
            <p>
              3) Nếu máy chặn cài đặt, hãy bật quyền <strong>Cài ứng dụng không rõ nguồn gốc</strong> cho trình duyệt hoặc trình quản lý tệp.
            </p>
          </div>
          <h2>Câu hỏi thường gặp</h2>
          <div className="faq-list">
            {faqs.map((item, index) => {
              const isOpen = openFaq === index;
              return (
                <article key={item.q} className={`faq-item ${isOpen ? "open" : ""}`}>
                  <button
                    type="button"
                    onClick={() => setOpenFaq(isOpen ? -1 : index)}
                    className="faq-question"
                  >
                    <span>{item.q}</span>
                    <span>{isOpen ? "−" : "+"}</span>
                  </button>
                  {isOpen && <p>{item.a}</p>}
                </article>
              );
            })}
          </div>
        </section>

        <section className="final-cta container">
          <h2>
            Sẵn sàng để tối nay
            <br />
            không còn câu hỏi “Ăn gì bây giờ?”
          </h2>
          <p>
            Tải Bếp Trợ Lý miễn phí ngay hôm nay và biến nguyên liệu sẵn có
            thành bữa ăn ngon, nhanh, đỡ áp lực.
          </p>
          <div className="cta-row">
            <a
              className="btn btn-primary"
              href={APK_DOWNLOAD_URL}
              target="_blank"
              rel="noreferrer"
            >
              Tải APK ngay
            </a>
            <a className="btn btn-secondary" href="#huong-dan-cai-apk">
              Xem hướng dẫn cài
            </a>
          </div>
        </section>
      </main>

      <footer className="footer">
        <div className="container footer-inner">
          <span>Bếp Trợ Lý • Nấu ngon từ những gì bạn có</span>
          <span>© {new Date().getFullYear()} Bếp Trợ Lý</span>
        </div>
      </footer>
    </div>
  );
}

export default App;
