package funkin.multiplayer.relay;

#if sys
/**
 * Ponto de entrada pra rodar o relay como processo separado, fora do
 * jogo — igual o MultiplayerServer, isso NÃO roda dentro do jogo.exe,
 * é um segundo programinha que fica ligado sozinho.
 *
 * COMPILAR (rodando a partir da raiz do projeto; ajusta "-cp source"
 * se a pasta do código-fonte do jogo tiver outro nome):
 *
 *   Neko (mais simples, precisa do neko instalado):
 *     haxe -cp source -main funkin.multiplayer.relay.RelayServerMain -neko relay-server.n
 *     neko relay-server.n
 *
 *   Executável nativo (precisa de hxcpp instalado):
 *     haxe -cp source -main funkin.multiplayer.relay.RelayServerMain -cpp relay-server-build
 *     ./relay-server-build/RelayServerMain          (Linux/Mac)
 *     relay-server-build\RelayServerMain.exe        (Windows)
 *
 * USO:
 *   Porta padrão 8090. Pra mudar, passa como argumento:
 *     neko relay-server.n 8090
 *
 * TESTE LOCAL (o que você tá fazendo agora):
 *   Só roda esse processo no seu PC e deixa o jogo apontando pra
 *   127.0.0.1:8090 (é o default do MultiplayerInviteService.connect()).
 *   Host e convidado citando o mesmo relay = já dá pra buscar e
 *   convidar, mesmo em janelas/processos diferentes do jogo na mesma
 *   máquina.
 *
 * QUANDO TIVER UMA MÁQUINA SEMPRE LIGADA (ex: a Xeon com DuckDNS):
 *   Roda esse mesmo processo lá, libera a porta 8090 no roteador
 *   (port forward TCP), e troca o host que o jogo usa pro seu domínio
 *   DuckDNS (MultiplayerInviteService.instance.connect(account,
 *   'seunome.duckdns.org', 8090)). O resto do protocolo não muda nada.
 */
class RelayServerMain
{
  public static function main():Void
  {
    var port:Int = 8090;
    var args:Array<String> = Sys.args();
    if (args.length > 0)
    {
      var parsed:Null<Int> = Std.parseInt(args[0]);
      if (parsed != null) port = parsed;
    }

    var server:RelayServer = new RelayServer(port);
    server.start();

    Sys.println('=================================');
    Sys.println(' Relay de matchmaking rodando');
    Sys.println(' Porta: ' + port);
    Sys.println(' Ctrl+C pra parar');
    Sys.println('=================================');

    while (server.running)
    {
      Sys.sleep(1);
    }
  }
}
#end
