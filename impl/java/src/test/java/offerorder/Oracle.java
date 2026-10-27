package offerorder;

import com.fasterxml.jackson.databind.JsonNode;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;

/**
 * A running {@code lake exe oracle} process: the Lean model answering one JSON
 * request per line.  Start it once per test class; each request costs a pipe
 * round trip, not a Lean start.
 */
final class Oracle implements AutoCloseable {
  private final Process process;
  private final BufferedWriter in;
  private final BufferedReader out;

  private Oracle(Process process) {
    this.process = process;
    this.in = new BufferedWriter(new OutputStreamWriter(process.getOutputStream(), StandardCharsets.UTF_8));
    this.out = new BufferedReader(new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8));
  }

  /** The repository root, where lake runs. Set by Maven from pom.xml. */
  static File repoRoot() {
    return new File(System.getProperty("repo.root", "../..")).getAbsoluteFile();
  }

  static Oracle start() throws IOException {
    Process p = new ProcessBuilder("lake", "exe", "oracle")
        .directory(repoRoot())
        .redirectError(ProcessBuilder.Redirect.INHERIT)
        .start();
    return new Oracle(p);
  }

  /** The model's answer to one request. */
  synchronized JsonNode ask(JsonNode request) {
    try {
      in.write(ModelJson.MAPPER.writeValueAsString(request));
      in.newLine();
      in.flush();
      String line = out.readLine();
      if (line == null) {
        throw new IllegalStateException("the oracle exited");
      }
      JsonNode reply = ModelJson.MAPPER.readTree(line);
      if (reply.has("failure")) {
        throw new IllegalStateException("the oracle could not read " + request + ": " + reply.get("failure"));
      }
      return reply;
    } catch (IOException e) {
      throw new IllegalStateException(e);
    }
  }

  @Override
  public void close() throws IOException {
    in.close();
    process.destroy();
  }
}
