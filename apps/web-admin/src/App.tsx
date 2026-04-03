import { FormEvent, useEffect, useMemo, useState } from "react";
import { BarChart, Bar, CartesianGrid, Legend, LineChart, Line, PieChart, Pie, Cell, Tooltip, XAxis, YAxis, ResponsiveContainer } from "recharts";
import { api, clearAuthToken, getAuthToken, LoginResponse, MemberPayload, OverviewResponse, setAuthToken } from "./api/client";

type RequestItem = {
  _id: string;
  description: string;
  imageUrl: string;
  imageUrls?: string[];
  status: string;
  currentQuote: number;
  createdAt: string;
  adminQuote?: number;
  adminQuoteMessage?: string;
  lastUserCounterMessage?: string;
  quotePendingForUser?: boolean;
  userId?: {
    fullName?: string;
    email?: string;
    phone?: string;
    campusId?: string;
  };
  latestNegotiation?: {
    senderRole?: string;
    offeredAmount?: number;
    message?: string;
    createdAt?: string;
  };
  negotiationCount?: number;
};

type MemberItem = {
  _id: string;
  fullName: string;
  email: string;
  phone: string;
  campusId: string;
  department?: string;
  createdAt: string;
};

type TabKey = "dashboard" | "requests" | "members";

const COLORS = ["#174A41", "#E4892D", "#2F7D6A", "#B33A3A", "#235789", "#6E8E59"];

const initialMember: MemberPayload = {
  fullName: "",
  email: "",
  phone: "",
  campusId: "MAIN-CAMPUS",
  department: "",
  password: ""
};

export default function App() {
  const [overview, setOverview] = useState<OverviewResponse | null>(null);
  const [requests, setRequests] = useState<RequestItem[]>([]);
  const [members, setMembers] = useState<MemberItem[]>([]);
  const [memberForm, setMemberForm] = useState<MemberPayload>(initialMember);
  const [message, setMessage] = useState<string>("");
  const [isAuthenticated, setIsAuthenticated] = useState(Boolean(getAuthToken()));
  const [activeTab, setActiveTab] = useState<TabKey>("dashboard");
  const [statusFilter, setStatusFilter] = useState<string>("ALL");
  const [busyRequestId, setBusyRequestId] = useState<string>("");
  const [quoteAmountByRequest, setQuoteAmountByRequest] = useState<Record<string, string>>({});
  const [quoteMessageByRequest, setQuoteMessageByRequest] = useState<Record<string, string>>({});
  const [loginForm, setLoginForm] = useState({
    email: "admin@eco-campus.local",
    password: "Admin@12345"
  });

  useEffect(() => {
    if (isAuthenticated) {
      void loadData();
    }
  }, [isAuthenticated]);

  useEffect(() => {
    if (!isAuthenticated) return;

    const timer = setInterval(() => {
      void loadData();
    }, 12000);

    return () => clearInterval(timer);
  }, [isAuthenticated]);

  async function loadData() {
    try {
      const [overviewRes, requestRes, membersRes] = await Promise.all([
        api.get<OverviewResponse>("/admin/analytics/overview"),
        api.get<{ requests: RequestItem[] }>("/admin/requests"),
        api.get<{ members: MemberItem[] }>("/admin/members")
      ]);
      setOverview(overviewRes.data);
      setRequests(requestRes.data.requests);
      setMembers(membersRes.data.members);
    } catch {
      clearAuthToken();
      setIsAuthenticated(false);
      setMessage("Unable to load admin data. Please log in again.");
    }
  }

  async function submitLogin(event: FormEvent) {
    event.preventDefault();
    setMessage("");

    try {
      const response = await api.post<LoginResponse>("/auth/login", loginForm);
      setAuthToken(response.data.accessToken);
      setIsAuthenticated(true);
      setMessage(`Logged in as ${response.data.user.fullName}.`);
      await loadData();
    } catch {
      clearAuthToken();
      setIsAuthenticated(false);
      setMessage("Login failed. Check the admin email and password.");
    }
  }

  function handleLogout() {
    clearAuthToken();
    setIsAuthenticated(false);
    setOverview(null);
    setRequests([]);
    setMembers([]);
    setMessage("Logged out.");
  }

  const trendData = useMemo(() => {
    const grouped = requests.reduce<Record<string, number>>((acc, req) => {
      const day = new Date(req.createdAt).toISOString().slice(0, 10);
      acc[day] = (acc[day] || 0) + 1;
      return acc;
    }, {});

    return Object.entries(grouped)
      .map(([day, count]) => ({ day, count }))
      .sort((a, b) => a.day.localeCompare(b.day));
  }, [requests]);

  const categoryLikeData = useMemo(() => {
    const categories: Record<string, number> = {
      Phones: 0,
      Laptops: 0,
      Batteries: 0,
      Cables: 0,
      Accessories: 0
    };

    requests.forEach((request) => {
      const text = request.description.toLowerCase();
      if (text.includes("phone")) categories.Phones += 1;
      if (text.includes("laptop")) categories.Laptops += 1;
      if (text.includes("battery")) categories.Batteries += 1;
      if (text.includes("cable") || text.includes("charger")) categories.Cables += 1;
      if (text.includes("mouse") || text.includes("keyboard") || text.includes("accessory")) categories.Accessories += 1;
    });

    return Object.entries(categories).map(([name, value]) => ({ name, value }));
  }, [requests]);

  const filteredRequests = useMemo(() => {
    if (statusFilter === "ALL") return requests;
    return requests.filter((request) => request.status === statusFilter);
  }, [requests, statusFilter]);

  const statuses = useMemo(() => {
    const values = Array.from(new Set(requests.map((item) => item.status)));
    return ["ALL", ...values];
  }, [requests]);

  async function submitMember(event: FormEvent) {
    event.preventDefault();
    setMessage("");

    try {
      await api.post("/admin/members", memberForm);
      setMemberForm(initialMember);
      setMessage("Campus member registered successfully.");
      await loadData();
    } catch {
      setMessage("Failed to register member. Check API auth and payload.");
    }
  }

  async function submitQuote(requestId: string) {
    const amount = Number(quoteAmountByRequest[requestId] || "0");
    if (!Number.isFinite(amount) || amount <= 0) {
      setMessage("Enter a valid quote amount.");
      return;
    }

    setBusyRequestId(requestId);
    setMessage("");

    try {
      await api.patch(`/admin/requests/${requestId}/quote`, {
        amount,
        message: quoteMessageByRequest[requestId] || ""
      });
      setMessage("Quote updated successfully.");
      await loadData();
    } catch {
      setMessage("Unable to set quote for this request.");
    } finally {
      setBusyRequestId("");
    }
  }

  async function rejectRequest(requestId: string) {
    setBusyRequestId(requestId);
    setMessage("");

    try {
      await api.patch(`/admin/requests/${requestId}/reject`, {
        reason: quoteMessageByRequest[requestId] || "Rejected by admin"
      });
      setMessage("Request denied.");
      await loadData();
    } catch {
      setMessage("Unable to reject request.");
    } finally {
      setBusyRequestId("");
    }
  }

  return (
    <div className="admin-shell">
      <header className="topbar">
        <div>
          <p className="kicker">Eco-Campus Platform</p>
          <h1>E-Waste Admin Studio</h1>
        </div>
        {isAuthenticated ? (
          <div className="topbar-actions">
            <button className="ghost-btn" type="button" onClick={() => void loadData()}>Refresh</button>
            <button className="ghost-btn" type="button" onClick={handleLogout}>Log out</button>
          </div>
        ) : null}
      </header>

      {!isAuthenticated ? (
        <section className="login-wrap">
          <article className="panel login-panel">
            <h2>Admin Login</h2>
            <p>Access requests, set quotes, and manage member operations.</p>
            <form className="member-form" onSubmit={submitLogin}>
              <input placeholder="Admin Email" type="email" value={loginForm.email} onChange={(e) => setLoginForm({ ...loginForm, email: e.target.value })} required />
              <input placeholder="Password" type="password" value={loginForm.password} onChange={(e) => setLoginForm({ ...loginForm, password: e.target.value })} required />
              <button type="submit">Sign in</button>
            </form>
            {message ? <p className="message">{message}</p> : null}
          </article>
        </section>
      ) : (
        <>
          <nav className="tab-nav">
            <button className={activeTab === "dashboard" ? "tab active" : "tab"} onClick={() => setActiveTab("dashboard")}>Dashboard</button>
            <button className={activeTab === "requests" ? "tab active" : "tab"} onClick={() => setActiveTab("requests")}>Request Management</button>
            <button className={activeTab === "members" ? "tab active" : "tab"} onClick={() => setActiveTab("members")}>Members</button>
          </nav>

          {activeTab === "dashboard" ? (
            <>
              <section className="kpi-grid">
                <article className="kpi-card">
                  <h3>Total Requests</h3>
                  <p>{overview?.totalRequests ?? 0}</p>
                </article>
                <article className="kpi-card">
                  <h3>Collected</h3>
                  <p>{overview?.collected ?? 0}</p>
                </article>
                <article className="kpi-card">
                  <h3>Students</h3>
                  <p>{overview?.users ?? 0}</p>
                </article>
                <article className="kpi-card">
                  <h3>Campus Members</h3>
                  <p>{overview?.members ?? 0}</p>
                </article>
              </section>

              <section className="chart-grid">
                <article className="panel">
                  <h2>Collection Trend</h2>
                  <ResponsiveContainer width="100%" height={250}>
                    <LineChart data={trendData}>
                      <CartesianGrid strokeDasharray="4 4" />
                      <XAxis dataKey="day" />
                      <YAxis />
                      <Tooltip />
                      <Legend />
                      <Line type="monotone" dataKey="count" stroke="#174A41" strokeWidth={3} />
                    </LineChart>
                  </ResponsiveContainer>
                </article>

                <article className="panel">
                  <h2>Common E-Waste Categories</h2>
                  <ResponsiveContainer width="100%" height={250}>
                    <BarChart data={categoryLikeData}>
                      <CartesianGrid strokeDasharray="4 4" />
                      <XAxis dataKey="name" />
                      <YAxis />
                      <Tooltip />
                      <Bar dataKey="value" fill="#E4892D" radius={[8, 8, 0, 0]} />
                    </BarChart>
                  </ResponsiveContainer>
                </article>

                <article className="panel">
                  <h2>Status Distribution</h2>
                  <ResponsiveContainer width="100%" height={250}>
                    <PieChart>
                      <Pie data={overview?.byStatus ?? []} dataKey="count" nameKey="_id" cx="50%" cy="50%" outerRadius={80}>
                        {(overview?.byStatus ?? []).map((_, index) => (
                          <Cell key={index} fill={COLORS[index % COLORS.length]} />
                        ))}
                      </Pie>
                      <Tooltip />
                    </PieChart>
                  </ResponsiveContainer>
                </article>
              </section>
            </>
          ) : null}

          {activeTab === "requests" ? (
            <section className="panel request-panel">
              <div className="request-header">
                <h2>Quote and Decision Desk</h2>
                <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
                  {statuses.map((status) => (
                    <option key={status} value={status}>{status}</option>
                  ))}
                </select>
              </div>
              <p className="subtle">Set quote values, add notes, or deny requests from one place.</p>

              <div className="request-list">
                {filteredRequests.map((request) => {
                  const previewImages = request.imageUrls?.length ? request.imageUrls : request.imageUrl ? [request.imageUrl] : [];
                  const adminQuote = request.adminQuote && request.adminQuote > 0 ? request.adminQuote : request.currentQuote;
                  const isClosedForAdmin = ["AGREED", "QR_ISSUED", "COLLECTED", "CANCELLED"].includes(request.status);
                  return (
                    <article key={request._id} className="request-card">
                      <div className="request-meta">
                        <span>#{request._id.slice(-6)}</span>
                        <span className={`status-pill status-${request.status.toLowerCase()}`}>{request.status}</span>
                      </div>

                      <h3>{request.description}</h3>
                      <p className="subtle">
                        Student: {request.userId?.fullName || "Unknown"} · {request.userId?.email || "No email"}
                      </p>
                      <div className="quote-summary">
                        <span>Admin quote: {adminQuote.toFixed(2)}</span>
                        <span>Negotiations: {request.negotiationCount ?? 0}</span>
                      </div>

                      {request.adminQuoteMessage ? <p className="negotiation-line">Admin reason: {request.adminQuoteMessage}</p> : null}
                      {request.lastUserCounterMessage ? <p className="negotiation-line">Student reason: {request.lastUserCounterMessage}</p> : null}

                      {request.latestNegotiation ? (
                        <div className="negotiation-box">
                          <p className="negotiation-title">
                            {request.latestNegotiation.senderRole === "USER" ? "Student re-quote" : "Admin quote"}
                          </p>
                          <p className="negotiation-line">Amount: {(request.latestNegotiation.offeredAmount ?? 0).toFixed(2)}</p>
                          {request.latestNegotiation.message ? <p className="negotiation-line">Reason: {request.latestNegotiation.message}</p> : null}
                        </div>
                      ) : null}

                      {previewImages.length > 0 ? (
                        <div className="image-strip">
                          {previewImages.slice(0, 4).map((url, idx) => (
                            <img key={`${request._id}-${idx}`} src={url} alt="waste preview" />
                          ))}
                        </div>
                      ) : null}

                      <div className="action-grid">
                        <input
                          type="number"
                          placeholder="Quote amount"
                          value={quoteAmountByRequest[request._id] ?? String(request.currentQuote || "")}
                          onChange={(e) => setQuoteAmountByRequest((prev) => ({ ...prev, [request._id]: e.target.value }))}
                        />
                        <input
                          type="text"
                          placeholder="Quote note / rejection reason"
                          value={quoteMessageByRequest[request._id] ?? ""}
                          onChange={(e) => setQuoteMessageByRequest((prev) => ({ ...prev, [request._id]: e.target.value }))}
                        />
                        <div className="row-btns">
                          <button disabled={busyRequestId === request._id || isClosedForAdmin} onClick={() => void submitQuote(request._id)} type="button">Send Quote</button>
                          <button disabled={busyRequestId === request._id || isClosedForAdmin} className="danger" onClick={() => void rejectRequest(request._id)} type="button">Deny</button>
                        </div>
                        {isClosedForAdmin ? <p className="subtle">This request is closed. Quote/deny actions are disabled.</p> : null}
                      </div>
                    </article>
                  );
                })}
              </div>
            </section>
          ) : null}

          {activeTab === "members" ? (
            <section className="members-layout">
              <article className="panel">
                <h2>Register Campus Member</h2>
                <form className="member-form" onSubmit={submitMember}>
                  <input placeholder="Full Name" value={memberForm.fullName} onChange={(e) => setMemberForm({ ...memberForm, fullName: e.target.value })} required />
                  <input placeholder="Email" type="email" value={memberForm.email} onChange={(e) => setMemberForm({ ...memberForm, email: e.target.value })} required />
                  <input placeholder="Phone" value={memberForm.phone} onChange={(e) => setMemberForm({ ...memberForm, phone: e.target.value })} required />
                  <input placeholder="Campus ID" value={memberForm.campusId} onChange={(e) => setMemberForm({ ...memberForm, campusId: e.target.value })} required />
                  <input placeholder="Department" value={memberForm.department} onChange={(e) => setMemberForm({ ...memberForm, department: e.target.value })} />
                  <input placeholder="Temporary Password" value={memberForm.password} onChange={(e) => setMemberForm({ ...memberForm, password: e.target.value })} required />
                  <button type="submit">Create Member</button>
                </form>
              </article>

              <article className="panel">
                <h2>Member Directory</h2>
                <div className="table-wrap">
                  <table>
                    <thead>
                      <tr>
                        <th>Name</th>
                        <th>Email</th>
                        <th>Campus</th>
                        <th>Phone</th>
                      </tr>
                    </thead>
                    <tbody>
                      {members.map((member) => (
                        <tr key={member._id}>
                          <td>{member.fullName}</td>
                          <td>{member.email}</td>
                          <td>{member.campusId}</td>
                          <td>{member.phone}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </article>
            </section>
          ) : null}

          {message ? <p className="message global-message">{message}</p> : null}
        </>
      )}
    </div>
  );
}
